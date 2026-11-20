#!/usr/bin/env python3
"""Publish one previously built and verified candidate; only within authorized job."""
import argparse
import hashlib
import http.client
import json
import os
from pathlib import Path
from urllib.error import HTTPError
from urllib.parse import urlencode, urlsplit
from urllib.request import HTTPRedirectHandler, Request, build_opener
from verify_candidate import ASSETS, MANIFEST, SOURCE, TAG, require, verify

SLUG = "lemoncat7/MountainStill"
RELEASE_ID = 445113228
PREVIOUS_LATEST = "v1.3.40"
EXPECTED_MAIN = "8d5cd78fcca920996ed4323467fcf62402f7f30b"
EXECUTION_REF = "refs/heads/ci/v1.3.41-publish-retry"
BASE = f"https://api.github.com/repos/{SLUG}"
ONE = f"/releases/{RELEASE_ID}"
NOTES = """本版改进换装比较：第 3 页显示战斗真气上限和每秒回气，并与吐纳修为区分。

此版本的附件由 GitHub Actions 从固定标签提交 `121ff2517188a28d3b89cfa6ce9a5faf3ce3d879` 重新构建，不是先前留存的候选文件。已校验附件大小、SHA-256、ZIP 完整性和更新清单。Windows/macOS 原生启动、界面和真实硬件表现尚待验收，请勿将本次打包检查视作原生验收。安装后若有问题，可回退到 v1.3.40。

已知限制：桌面透明度问题未证实修复；Windows EXE 未经发行商 Authenticode 签名，macOS 为 ad-hoc 签名，未经 Developer ID 签名或 Apple 公证。物理 GPU、音频、DPI、多显示器、长期混合负载尚未验收。此前 GUI 结果不确定，Windows 观察使用软件渲染/Dummy 音频，ARM 长测仅覆盖采集；历史两项剑节奏断言失败仍保留。这些前次结果不归属于本次新字节。
"""

class SafeRedirects(HTTPRedirectHandler):
    """Never forward API Authorization to asset storage or an unexpected host."""
    def redirect_request(self, req, fp, code, msg, headers, newurl):
        old, new = urlsplit(req.full_url), urlsplit(newurl)
        require(req.get_method() == "GET" and new.scheme == "https" and new.hostname and
                (new.hostname == "github.com" or new.hostname == "api.github.com"
                 or new.hostname.endswith(".githubusercontent.com")),
                "Unexpected redirect (credentials not forwarded)")
        nxt = super().redirect_request(req, fp, code, msg, headers, newurl)
        if old.netloc != new.netloc:
            nxt.remove_header("Authorization")
            nxt.headers.pop("Authorization", None)
            nxt.unredirected_hdrs.pop("Authorization", None)
        return nxt

OPENER = build_opener(SafeRedirects())

def headers(token="", accept="application/vnd.github+json"):
    result = {"Accept": accept, "User-Agent": "MountainStill-v1341-verified-publisher",
              "X-GitHub-Api-Version": "2022-11-28", "Cache-Control": "no-cache"}
    if token:
        result["Authorization"] = "Bearer " + token
    return result

def api(path, token="", payload=None):
    kw = dict(headers=headers(token))
    if payload is not None:
        kw["headers"]["Content-Type"] = "application/json"
        kw["data"] = json.dumps(payload).encode()
        kw["method"] = "PATCH"
    with OPENER.open(Request(BASE + path, **kw), timeout=45) as r:
        return json.load(r)

def uploaded_assets(release):
    raw = release["assets"]
    entries = {a["name"]: a for a in raw}
    require(len(entries) == len(raw) and all(n in ASSETS for n in entries), "Foreign or duplicate release assets")
    return entries

def reference(token):
    require(api("/git/ref/heads/main", token)["object"]["sha"] == EXPECTED_MAIN, "Main reference changed")
    ref = api(f"/git/ref/tags/{TAG}", token)["object"]
    if ref["type"] == "tag":
        ref = api("/git/tags/" + ref["sha"], token)["object"]
    require(ref["type"] == "commit" and ref["sha"] == SOURCE, "Release tag moved")

def state(token, *, draft, prerelease, names):
    data = api(ONE, token)
    require(data["id"] == RELEASE_ID and data["tag_name"] == TAG and data["draft"] is draft
            and data["prerelease"] is prerelease and not data.get("immutable"),
            "Unexpected release identity, draft/prerelease state, or immutability")
    assets = uploaded_assets(data)
    require(set(names) == set(assets), "Unexpected release assets")
    return assets

def upload(file, token, expected):
    connection = http.client.HTTPSConnection("uploads.github.com", timeout=180)
    route = f"/repos/{SLUG}/releases/{RELEASE_ID}/assets?" + urlencode({"name": file.name})
    typ = "application/zip" if file.suffix == ".zip" else "application/octet-stream"
    hdr = headers(token) | {"Content-Type": typ, "Content-Length": str(expected["size"])}
    try:
        with file.open("rb") as stream:
            connection.request("POST", route, body=stream, headers=hdr)
        r = connection.getresponse()
        require(r.status == 201, f"Upload not confirmed for {file.name}: HTTP {r.status}; do not retry writes blindly")
        result = json.load(r)
        metadata(result, file.name, expected)
        return result
    finally:
        connection.close()

def metadata(asset, name, expected):
    require(asset["name"] == name and asset["size"] == expected["size"] and asset.get("state") == "uploaded",
            f"Unexpected uploaded metadata for {name}")
    require(asset.get("digest") == "sha256:" + expected["sha256"], f"Missing or mismatched GitHub digest for {name}")

def readback(asset, name, expected, token=""):
    metadata(asset, name, expected)
    if token:
        asset_id = asset["id"]
        require(type(asset_id) is int and asset_id > 0, "Invalid asset ID")
        url = f"{BASE}/releases/assets/{asset_id}"
    else:
        url = f"https://github.com/{SLUG}/releases/download/{TAG}/{name}"
        require(url == asset["browser_download_url"], "Unexpected public download destination")
    size, sha = 0, hashlib.sha256()
    with OPENER.open(Request(url, headers=headers(token, "application/octet-stream")), timeout=180) as r:
        while data := r.read(1024**2):
            size += len(data)
            require(size <= expected["size"], f"Readback exceeds pinned size: {name}")
            sha.update(data)
    require(size == expected["size"] and sha.hexdigest() == expected["sha256"],
            f"Readback digest mismatch: {name}")

def previous_latest(token):
    require(api("/releases/latest", token)["tag_name"] == PREVIOUS_LATEST, "Latest changed from v1.3.40")

def anonymous_pages(expected_status):
    # Official web endpoints, explicitly unauthenticated; never REST token evidence.
    for path in (f"/releases/tag/{TAG}", f"/releases/expanded_assets/{TAG}"):
        url = f"https://github.com/{SLUG}" + path
        try:
            with OPENER.open(Request(url, headers=headers()), timeout=45) as response:
                require(response.geturl() == url, "Anonymous page redirected unexpectedly")
                code = response.status
        except HTTPError as error:
            require(error.url == url, "Anonymous error came from another destination")
            code = error.code
        require(code == expected_status, f"Anonymous official page {path}: expected {expected_status}, got {code}")
        print(f"ANONYMOUS_WEB: {path} HTTP {code}", flush=True)

def draft_invisible():
    anonymous_pages(404)

def preflight(token):
    reference(token)
    previous_latest(token)
    state(token, draft=False, prerelease=True, names=())
    print("Authenticated read-only preflight passed; no mutation", flush=True)

def publish(root, report, token):
    print("STAGE: offline candidate verification", flush=True)
    expected = verify(root, report)
    print(json.dumps(expected, sort_keys=True), flush=True)
    require(ASSETS[-1] == MANIFEST, "Manifest must upload last")
    reference(token)
    previous_latest(token)
    state(token, draft=False, prerelease=True, names=())
    print("STAGE: convert exact empty prerelease to private draft", flush=True)
    changed = api(ONE, token, {"draft": True})
    require(changed["draft"] is True and changed["prerelease"] is True, "Published prerelease could not be converted to draft")
    state(token, draft=True, prerelease=True, names=())
    draft_invisible()
    previous_latest(token)
    staged = []
    for name in ASSETS:
        if name == MANIFEST:
            reference(token)
            draft_invisible()
            current = state(token, draft=True, prerelease=True, names=staged)
            for n in staged:
                metadata(current[n], n, expected[n])
        print("STAGE: upload then authenticated readback " + name, flush=True)
        asset = upload(root / name, token, expected[name])
        readback(asset, name, expected[name], token)
        staged.append(name)
        print(f"Private draft asset verified: {name} {expected[name]['sha256']}", flush=True)
    assets = state(token, draft=True, prerelease=True, names=ASSETS)
    for name in ASSETS:
        metadata(assets[name], name, expected[name])
    draft_invisible()
    reference(token)
    previous_latest(token)
    run_url = f"https://github.com/{SLUG}/actions/runs/{os.environ["GITHUB_RUN_ID"]}"
    body = NOTES + "\n本次构建与公开下载核验：" + run_url + "\n\n```text\n" + "".join(expected[n]["sha256"] + "  " + n + "\n" for n in ASSETS) + "```\n"
    print("STAGE: promote seven verified draft assets to public Latest", flush=True)
    result = api(ONE, token, {"draft": False, "prerelease": False, "make_latest": "true",
                             "name": "山隐 v1.3.41 · 正式版", "body": body})
    require(result["id"] == RELEASE_ID and result["draft"] is False and result["prerelease"] is False,
            "Promotion was not confirmed; check actual remote state, do not retry blindly")
    latest = api("/releases/latest", token)
    require(latest["id"] == RELEASE_ID and latest["tag_name"] == TAG
            and not latest["draft"] and not latest["prerelease"], "Public Latest does not confirm promotion")
    public = api(f"/releases/tags/{TAG}", token)
    assets = uploaded_assets(public)
    require(public["id"] == RELEASE_ID and not public["draft"] and not public["prerelease"]
            and set(assets) == set(ASSETS), "Public release metadata does not match the final release")
    anonymous_pages(200)
    for name in ASSETS:
        readback(assets[name], name, expected[name])
        print(f"Anonymous public download verified: {name} {expected[name]['sha256']}", flush=True)
    reference(token)
    require(api("/releases/latest", token)["id"] == RELEASE_ID, "Latest changed during public verification")
    print("Verified public Latest v1.3.41, exact source and all seven published assets.")

if __name__ == "__main__":
    ap = argparse.ArgumentParser(description=__doc__)
    ap.add_argument("directory", type=Path, nargs="?")
    ap.add_argument("build_report", type=Path, nargs="?")
    ap.add_argument("--preflight", action="store_true")
    args = ap.parse_args()
    require(os.getenv("GITHUB_ACTIONS") == "true" and os.getenv("RUNNER_ENVIRONMENT") == "github-hosted"
            and os.getenv("GITHUB_REPOSITORY") == SLUG and os.getenv("GITHUB_EVENT_NAME") == "push"
            and os.getenv("RUNNER_OS") == "Linux", "Only reviewed disposable standard upstream workflow")
    event = json.loads(Path(os.environ["GITHUB_EVENT_PATH"]).read_text())
    require(os.getenv("GITHUB_REF") == EXECUTION_REF and os.getenv("GITHUB_RUN_ATTEMPT") == "1"
            and event.get("created") is True and event.get("ref") == EXECUTION_REF
            and event.get("repository", {}).get("private") is False, "Only first execution-branch creation")
    token = os.environ["GH_TOKEN"]
    require(token, "Missing built-in token")
    if args.preflight:
        preflight(token)
    else:
        require(args.directory is not None and args.build_report is not None, "Candidate paths required")
        publish(args.directory, args.build_report, token)
