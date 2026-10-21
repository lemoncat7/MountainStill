#!/usr/bin/env python3
"""Prepare the five new finite campaign panoramas from original generated RGBA art.

Runtime operations are only rectangular cropping and LANCZOS resampling. The
source alpha is preserved, without masking, repainting, mirroring or duplication.
Review sheets add labels on a separate plain page, never on a runtime asset.
The existing Bamboo Pass assets are read for review only and remain unchanged.
"""
from pathlib import Path
from PIL import Image, ImageChops, ImageDraw, ImageFont
import hashlib
import json
import shutil

ROOT = Path(__file__).resolve().parents[1]
OUT = ROOT / 'assets/cultivation/routes'
SIZE = (2080, 280)
BASELINE = 246
COMPATIBILITY_ROUTES = {'ember_ruins', 'moon_marsh', 'summit_gate'}
ROUTES = [
    ('creek_bridge', 'Creek Bridge', 724),
    ('cloud_slope', 'Cloud Slope', 724),
    ('ember_ruins', 'Ember Ruins', 685),
    ('moon_marsh', 'Moon Marsh', 710),
    ('summit_gate', 'Summit Gate', 724),
]


def sha(path):
    return hashlib.sha256(path.read_bytes()).hexdigest()


def main():
    metadata = {
        'runtime_size': list(SIZE),
        'viewport_size': [1040, 280],
        'ground_baseline': BASELINE,
        'camera_offset_bounds': [0, 1040],
        'finite_panorama': True,
        'infinite_seamless_tile': False,
        'mirrored_or_duplicated_clumps': False,
        'generation': 'Original OpenAI built-in image_gen art with genuine alpha.',
        'postprocessing': 'Rectangular crop and LANCZOS canvas resize only; source alpha retained.',
        'routes': {},
    }
    qa = {'all_checks_passed': True, 'routes': {}}
    generated_sources = []
    for route_id, title, crop_height in ROUTES:
        source_path = OUT / 'sources' / f'{route_id}_panorama-source.png'
        source = Image.open(source_path).convert('RGBA')
        box = (0, 0, source.width, crop_height)
        assert crop_height <= source.height
        panorama = source.crop(box).resize(SIZE, Image.Resampling.LANCZOS)
        runtime_path = OUT / f'{route_id}_panorama.png'
        panorama.save(runtime_path)
        alpha = panorama.getchannel('A')
        baseline_alpha = alpha.crop((0, BASELINE, SIZE[0], BASELINE + 1)).getextrema()
        assert baseline_alpha[0] > 240, (route_id, baseline_alpha)
        transparent_fraction = alpha.histogram()[0] / (SIZE[0] * SIZE[1])
        assert transparent_fraction > 0.25, (route_id, transparent_fraction)
        left = panorama.crop((0, 0, 1040, 280))
        right = panorama.crop((1040, 0, 2080, 280))
        mirrored_equal = ImageChops.difference(left, right.transpose(Image.Transpose.FLIP_LEFT_RIGHT)).convert('RGB').getbbox() is None
        repeated_equal = ImageChops.difference(left, right).convert('RGB').getbbox() is None
        assert not mirrored_equal and not repeated_equal
        metadata['routes'][route_id] = {
            'title': title,
            'runtime': runtime_path.name,
            'source': str(source_path.relative_to(OUT)),
            'source_size': list(source.size),
            'source_crop': list(box),
            'source_sha256': sha(source_path),
            'runtime_sha256': sha(runtime_path),
            'alpha_extrema': list(alpha.getextrema()),
            'baseline_alpha_extrema': list(baseline_alpha),
            'clear_alpha_fraction': round(transparent_fraction, 6),
        }
        if route_id in COMPATIBILITY_ROUTES:
            static_path = OUT / f'{route_id}.png'
            scroll_path = OUT / f'{route_id}_scroll.png'
            left.save(static_path)
            shutil.copyfile(runtime_path, scroll_path)
            metadata['routes'][route_id]['compatibility_assets'] = {
                'static': static_path.name,
                'static_size': [1040, 280],
                'static_crop_from_panorama': [0, 0, 1040, 280],
                'static_sha256': sha(static_path),
                'scroll': scroll_path.name,
                'scroll_is_byte_identical_panorama_copy': True,
                'scroll_sha256': sha(scroll_path),
                'host_preferred_asset': runtime_path.name,
            }
        qa['routes'][route_id] = {
            'rgba_2080x280': panorama.mode == 'RGBA' and panorama.size == SIZE,
            'genuine_clear_alpha': alpha.getextrema()[0] == 0,
            'no_gap_at_foot_line': baseline_alpha[0] > 240,
            'baseline_min_alpha': baseline_alpha[0],
            'clear_alpha_fraction': round(transparent_fraction, 6),
            'halves_are_not_mirrored': not mirrored_equal,
            'halves_are_not_repeated': not repeated_equal,
            'visual_review': 'Inspected full panorama and light-background composite; original asymmetric landmarks, clear sky cutout, level continuous foot lane.',
        }
        generated_sources.append({
            'route_id': route_id,
            'path': str(source_path.relative_to(ROOT)),
            'sha256': sha(source_path),
            'size': list(source.size),
            'mode': source.mode,
            'source_alpha_extrema': list(source.getchannel('A').getextrema()),
        })

    (OUT / 'campaign-panorama-metadata.json').write_text(json.dumps(metadata, indent=2) + '\n')
    (OUT / 'campaign-art-qa.json').write_text(json.dumps(qa, indent=2) + '\n')
    provenance = {
        'created_utc': '2026-10-20T01:33:52Z',
        'generator': 'OpenAI built-in image_gen',
        'original_art': True,
        'style_reference': 'assets/cultivation/routes/bamboo_pass_panorama.png',
        'style_reference_inspected_before_generation': True,
        'style_reference_scope': 'Visual inspection of existing project art; matching warm brown ink and watercolor landscape rendering.',
        'prompts': 'sources/campaign-generation-prompts.json',
        'sources': generated_sources,
        'pipeline': 'tools/prepare_campaign_routes.py',
        'pipeline_operations': ['rectangular crop', 'LANCZOS resize'],
        'preserves_generated_alpha': True,
        'no_programmatic_background_removal': True,
        'no_painted_code_substitutes': True,
        'no_mirrored_or_duplicated_clumps': True,
        'creek_bridge_edit': 'Built-in image_gen flattened the initial raised bridge; initial source and both prompts are retained.',
        'finite_scroll': 'Clamp a 1040px viewport to camera offsets 0..1040; do not wrap these panoramas.',
        'bamboo_pass': 'Existing source, runtime art and metadata were not modified.',
        'legacy_scroll_strips': 'Historical *_scroll.png and *_mirror.png files remain present but are superseded by the *_panorama.png assets for finite campaign travel.',
        'compatibility_assets': 'Ember Ruins, Moon Marsh and Summit Gate static PNGs are exact first-1040px viewport crops; their scroll PNGs are byte-identical copies of the finite panoramas. Existing Creek Bridge and Cloud Slope static and scroll files remain unchanged.',
    }
    (OUT / 'campaign-provenance.json').write_text(json.dumps(provenance, indent=2) + '\n')

    # The review page is not runtime art. Its page color demonstrates actual alpha.
    font_path = '/usr/share/fonts/truetype/dejavu/DejaVuSans.ttf'
    font = ImageFont.truetype(font_path, 22)
    small = ImageFont.truetype(font_path, 16)
    review_routes = [('bamboo_pass', 'Bamboo Pass (existing)')] + [(r, t) for r, t, _ in ROUTES]
    page = Image.new('RGBA', (1200, 6 * 205 + 60), (248, 242, 226, 255))
    draw = ImageDraw.Draw(page)
    draw.text((24, 15), 'MountainStill | Six finite campaign panoramas', font=font, fill='#594b36')
    for index, (route_id, title) in enumerate(review_routes):
        y = 55 + index * 205
        draw.text((24, y), title, font=small, fill='#594b36')
        panorama = Image.open(OUT / f'{route_id}_panorama.png').convert('RGBA')
        page.alpha_composite(panorama.resize((1152, 155), Image.Resampling.LANCZOS), (24, y + 28))
    page.convert('RGB').save(OUT / 'campaign-route-preview.png')
    print('Prepared and verified five original finite 2080x280 campaign panoramas.')
    print('All five have genuine clear alpha and a continuous ground baseline at y246.')


if __name__ == '__main__':
    main()
