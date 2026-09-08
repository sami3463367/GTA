"""Prevent reintroducing runtime placeholder terrain/wall/UI drawing."""
from pathlib import Path
import re
root=Path(__file__).resolve().parents[1]
for script in (root/'game/scripts').glob('*.gd'):
    name=script.name
    text=script.read_text()
    for forbidden in ['draw_rect(', 'draw_colored_polygon(', 'StyleBoxFlat.new(', 'Button.new(', 'ProgressBar.new(']:
        assert forbidden not in text, f'{name}: placeholder drawing {forbidden}'
assert 'TileMapLayer.new()' in (root/'game/scripts/city_renderer.gd').read_text()
assert 'CanvasModulate.new()' in (root/'game/scripts/city_renderer.gd').read_text()
assert 'PointLight2D.new()' in (root/'game/scripts/city_renderer.gd').read_text()
print('Asset/TileMap/lighting/custom-UI standards passed.')
