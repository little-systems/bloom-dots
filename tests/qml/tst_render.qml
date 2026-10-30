import QtQuick
import QtTest
import "../../shell/common"
import "../../shell/common/render"
import "../../shell/modules/notch"

// The shell scales whole stages (bloom-scale), but a layer renders at its
// item's own size, so a layered item would be stretched and blurry. Every
// layer's texture is sized by Render.scale.
Item {
	id: host
	width: 600
	height: 300

	AlbumArt { id: art; width: 24; height: 24 }
	TitleMarquee { id: title; y: 40; width: 120; text: "A title" }
	EdgeSurface { id: edge; y: 80; edge: "top"; pillWidth: 200; pillHeight: 36; edgeRadius: 10; farRadius: 18; flares: true }
	Ambience { id: amb; y: 140; width: 300; height: 132 }

	TestCase {
		name: "Render"
		when: windowShown

		function cleanup() { Render.scale = 1; }

		function layered(item, out) {
			if (item.layer && item.layer.enabled && !item.objectName.startsWith("filterBlur"))
				out.push(item);
			for (const c of item.children) layered(c, out);
			return out;
		}

		function test_layersRenderAtTheStageScale() {
			Render.scale = 2;
			for (const root of [art, title, edge, amb]) {
				const items = layered(root, []);
				verify(items.length > 0, `${root} has layers`);
				for (const it of items) {
					compare(it.layer.textureSize.width, Math.ceil(it.width * 2), `${root} / ${it} width`);
					compare(it.layer.textureSize.height, Math.ceil(it.height * 2), `${root} / ${it} height`);
				}
			}
		}

		function test_blurTexturesScaleToo() {
			Render.scale = 2;
			const f = findChild(amb, "glow");
			const src = findChild(f, "filterBlurSource");
			compare(src.layer.textureSize.width, Math.ceil(src.width * 2 / 8));
		}
	}
}
