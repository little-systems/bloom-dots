import QtQuick
import QtTest
import "../../shell/modules/notch"

// The agent row (Bloom AgentAlert.css): working labels carry a light sweep
// at 78% ink; finished ones are plain; the elapsed time uses tabular digits.
Item {
	id: host
	width: 300
	height: 40

	Component {
		id: rowComponent
		AgentActivity { width: 280; now: 5000; ink: "white" }
	}

	TestCase {
		name: "AgentActivity"
		when: windowShown

		function make(entry) {
			const r = createTemporaryObject(rowComponent, host, { entry: entry });
			verify(r !== null);
			return r;
		}

		function test_workingLabelsShimmer() {
			const r = make({ agent: "claude", kind: "working", activity: "editing", started: 0, received: 0 });
			const sweep = findChild(r, "shimmer");
			verify(sweep && sweep.visible, "the sweep shows while working");
			compare(sweep.periodMs, 3200);
			compare(Math.round(findChild(r, "status").color.a * 100), 78);
		}

		function test_finishedLabelsArePlain() {
			const r = make({ agent: "claude", kind: "ready", started: 0, received: 3000 });
			verify(!findChild(r, "shimmer").visible);
			compare(findChild(r, "status").color.a, 1);
			compare(findChild(r, "elapsed").text, "0:03");
		}

		function test_elapsedUsesTabularDigits() {
			const r = make({ agent: "codex", kind: "working", started: 0, received: 0 });
			compare(findChild(r, "elapsed").font.features["tnum"], 1);
		}
	}
}
