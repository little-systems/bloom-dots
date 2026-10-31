import QtQuick
import QtTest
import "../../shell/common/render"
import "../../shell/settings"

Item {
	id: host; width: 400; height: 200
	QtObject { id: fakeTheme; property color text:"white"; property color textMuted:"gray"; property color border:"gray"; property color groupBg:"black" }
	Component { id: label; Text { font.pixelSize: Fonts.px(16) } }
	Component { id: row; SRow { width: 400; icon:"type"; label:"A label"; desc:"A description"; theme:fakeTheme } }
	TestCase {
		name: "FontScale"
		function cleanup() { Render.uiScale = 1; Render.fontScale = 1; }
		function test_fontScaleIsIndependentOfGeometryScale() {
			Render.fontScale = 1.25; Render.uiScale = 1;
			const t = createTemporaryObject(label, host); compare(t.font.pixelSize, 20);
			Render.uiScale = 1.3;
			fuzzyCompare(t.font.pixelSize * Render.uiScale, 20, 1);
			Render.fontScale = 1;
			fuzzyCompare(t.font.pixelSize * Render.uiScale, 16, 1);
		}
		function test_settingRowsGrowToFitLargerText() {
			Render.fontScale = 1.6; Render.uiScale = 0.8;
			const r = createTemporaryObject(row, host);
			const label = findChild(r,"label"), desc = findChild(r,"desc");
			verify(label.height >= label.font.pixelSize * 1.2);
			verify(desc.height >= desc.font.pixelSize * 1.2);
			verify(r.height >= label.height + desc.height + 20);
		}
	}
}
