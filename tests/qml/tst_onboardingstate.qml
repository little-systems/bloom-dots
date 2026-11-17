import QtQuick
import QtTest
import "../../shell/modules/onboarding/onboarding.js" as Onboarding

// ~/.local/state/bloom/onboarding.json, written pending by a fresh install.
TestCase {
	name: "OnboardingState"

	function test_onlyAnExplicitPendingStateOpensTheGuide() {
		verify(Onboarding.pending('{"completed": false}\n'));
		verify(!Onboarding.pending('{"completed": true}\n'));
		verify(!Onboarding.pending(""), "no file (installed before the guide): no unsolicited guide");
		verify(!Onboarding.pending("not json"), "an unreadable file: no guide");
		verify(!Onboarding.pending('{"completed": "no"}'), "only a real false is pending");
	}

	function test_finishingWritesCompleted() {
		compare(Onboarding.serialize(true), '{"completed": true}\n');
		verify(!Onboarding.pending(Onboarding.serialize(true)));
	}
}
