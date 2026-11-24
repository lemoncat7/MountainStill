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
RELEASE_ID = None
PREVIOUS_LATEST = "v1.3.43"
EXPECTED_MAIN = SOURCE
EXECUTION_REF = "refs/heads/ci/v1.3.44-publish-once"
BASE = f"https://api.github.com/repos/{SLUG}"
ONE = None
NOTES = '本版修复连续接触中的落空过早清除上一击浮字的问题：命中、格挡和破势提示按原计时自然消退，落空不清零、不续时；下一次有效接触正常替换。HP同步、音效入口、接触特效、动作时序、伤害、角色比例、美术、桌面透明度、字体、存档schema4及Bootstrap ABI1保持不变。\n\n本次GitHub Actions从固定main/tag源码构建全新字节，完成Linux结构/CRC/大小/SHA、七件清单绑定及v1.3.43真实Windows/macOS载荷升级健康检查。稳定通道排除更高测试版的选择检查通过。这些不是Windows/macOS原生安装启动或GUI验收；原生验收后补。\n\n真实所得配装的正式host重放专项106项由6失败变为0；两场战斗接触事件摘要、胜负和耗时与修复前完全相同。独立审查未发现阻断。历史两条剑节奏6.8161秒低于7秒断言保留，未改战斗数值或放宽门槛；两首领片段43.4333秒仍不满足旧50–90秒录像门槛。\n\n保留限制：透明度/物理GPU黑底未证实修复；原生音频、DPI、多屏及长期混合负载未验收；Windows未发行商签名，macOS ad-hoc未公证。Linux有界混合运行通过不代表原生或长期稳定性。\n'


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
    result = {"Accept": accept, "User-Agent": "MountainStill-v1344-verified-publisher",
              "X-GitHub-Api-Version": "2022-11-28", "Cache-Control": "no-cache"}
    if token:
        result["Authorization"] = "Bearer " + token
    return result

def api(path, token="", payload=None, method="PATCH"):
    kw = dict(headers=headers(token))
    if payload is not None:
        kw["headers"]["Content-Type"] = "application/json"
        kw["data"] = json.dumps(payload).encode()
        kw["method"] = method
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
    require(api("/releases/latest", token)["tag_name"] == PREVIOUS_LATEST, "Latest changed from v1.3.43")

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

def private_asset_unavailable(name, token, staged):
    # The public tag remains visible. Probe only the actual uploaded binary URL.
    url = f"https://github.com/{SLUG}/releases/download/{TAG}/{name}"
    try:
        with OPENER.open(Request(url, headers=headers()), timeout=45) as response:
            response.read(1)
        raise ValueError("Draft asset URL returned a successful response; stop before manifest")
    except HTTPError as error:
        require(error.code in (401, 403, 404), f"Unexpected anonymous asset response: {error.code}")
        kind = "unavailable"
        if error.code == 403:
            body = error.read(4096).decode("utf-8", errors="replace").lower()
            limited = error.headers.get("X-RateLimit-Remaining") == "0" or "rate limit" in body
            kind = "rate-limited (not visibility proof)" if limited else "denied/ambiguous (not visibility proof)"
        state(token, draft=True, prerelease=True, names=staged)
        print(f"ANONYMOUS_ASSET: {name} HTTP {error.code}; {kind}; authenticated draft confirmed", flush=True)

def preflight(token):
    reference(token)
    previous_latest(token)
    # Authenticated list includes drafts. Refuse collisions, never reuse/overwrite.
    for page in range(1, 101):
        releases = api(f"/releases?per_page=100&page={page}", token)
        require(isinstance(releases, list), "Invalid release listing")
        require(not any(r.get("tag_name") == TAG for r in releases), "Target release already exists; stop without writes")
        if len(releases) < 100:
            print("Authenticated refs/latest/no-existing-release preflight passed", flush=True)
            return
    raise ValueError("Release listing exceeds safety bound")

def create_private_draft(token):
    global RELEASE_ID, ONE
    preflight(token)
    result = api("/releases", token, {"tag_name": TAG, "target_commitish": SOURCE,
                 "draft": True, "prerelease": True, "name": "山隐 v1.3.44 · 私有构建暂存"}, method="POST")
    require(type(result.get("id")) is int and result["id"] > 0 and result.get("tag_name") == TAG
            and result.get("draft") is True and result.get("prerelease") is True
            and result.get("assets") == [], "Private draft creation not confirmed; do not retry")
    RELEASE_ID = result["id"]
    ONE = f"/releases/{RELEASE_ID}"
    print(f"Created private draft ID {RELEASE_ID} for exact source {SOURCE}", flush=True)
    state(token, draft=True, prerelease=True, names=())

def publish(root, report, token):
    print("STAGE: offline candidate verification", flush=True)
    expected = verify(root, report)
    print(json.dumps(expected, sort_keys=True), flush=True)
    require(ASSETS[-1] == MANIFEST, "Manifest must upload last")
    reference(token)
    previous_latest(token)
    create_private_draft(token)
    print("STAGE: exact newly created private draft", flush=True)
    staged = []
    for name in ASSETS:
        if name == MANIFEST:
            reference(token)
            current = state(token, draft=True, prerelease=True, names=staged)
            for n in staged:
                metadata(current[n], n, expected[n])
        print("STAGE: upload then authenticated readback " + name, flush=True)
        asset = upload(root / name, token, expected[name])
        readback(asset, name, expected[name], token)
        staged.append(name)
        if len(staged) == 1:
            private_asset_unavailable(name, token, staged)
        print(f"Private draft asset verified: {name} {expected[name]['sha256']}", flush=True)
    assets = state(token, draft=True, prerelease=True, names=ASSETS)
    for name in ASSETS:
        metadata(assets[name], name, expected[name])
    reference(token)
    previous_latest(token)
    run_url = f"https://github.com/{SLUG}/actions/runs/{os.environ["GITHUB_RUN_ID"]}"
    body = NOTES + "\n固定 main/tag 源码：" + SOURCE + "\n本次构建与公开下载核验：" + run_url + "\n\n```text\n" + "".join(expected[n]["sha256"] + "  " + n + "\n" for n in ASSETS) + "```\n"
    print("STAGE: promote seven verified draft assets to public Latest", flush=True)
    result = api(ONE, token, {"draft": False, "prerelease": False, "make_latest": "true",
                             "name": "山隐 v1.3.44 · 正式版", "body": body})
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
    print("Verified public Latest v1.3.44, exact source and all seven published assets.")

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
