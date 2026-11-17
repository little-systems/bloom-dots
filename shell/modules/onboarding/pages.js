.pragma library

// The first-run guide's pages (docs/specs round 3, C): Bloom's flow and copy
// where it fits Linux (ui.onboarding.*), our own text under linux.onboarding.*.
var PAGES = [
	{ kind: "welcome", anchor: "center", title: "ui.onboarding.welcomeToBloom", description: "linux.onboarding.welcomeDesc", hints: [] },
	{ kind: "intro", anchor: "island", title: "ui.onboarding.meetTheIsland", description: "ui.onboarding.musicWidgetsAndQuickControlsTogetherAtTheTopOf",
		hints: ["ui.onboarding.hoverToRevealWidgets", "ui.onboarding.whileHoveringClickSwipeOrScrollToOpenAndSwitch",
			"ui.onboarding.findQuickControlsAndSettingsInCommandCenter", "linux.onboarding.dropOnTheIsland"] },
	{ kind: "island-mode", anchor: "island", title: "ui.onboarding.keepItInReach", description: "ui.onboarding.chooseWhenYourIslandStaysOnScreen", hints: [] },
	{ kind: "intro", anchor: "dock", title: "ui.onboarding.meetTheDock", description: "linux.onboarding.dockDesc",
		hints: ["ui.onboarding.hoverForWindowPreviews", "ui.onboarding.dragYourAppsToReorderThem", "linux.onboarding.rightClickForOptions"] },
	{ kind: "dock-mode", anchor: "dock", title: "ui.onboarding.giveYourAppsSomeSpace", description: "ui.onboarding.chooseWhenYourDockStaysOnScreen", hints: [] },
	{ kind: "controls", anchor: "center", title: "ui.onboarding.aLittleLessInterruption", description: "ui.onboarding.bloomBringsVolumeAndBrightnessControlsToTheSidesOf",
		hints: ["ui.onboarding.useYourKeyboardControlsAsUsual", "linux.onboarding.hoverAnEdge"] },
	{ kind: "keys", anchor: "center", title: "linux.onboarding.keysTitle", description: "linux.onboarding.keysDesc",
		hints: ["linux.onboarding.keysClipboard", "linux.onboarding.keysEmoji", "linux.onboarding.keysOverview", "linux.onboarding.keysCheatsheet"] },
	{ kind: "preferences", anchor: "center", title: "ui.onboarding.makeYourselfAtHome", description: "ui.onboarding.aFewSmallChoicesYourWay", hints: [] },
	{ kind: "finish", anchor: "center", title: "ui.onboarding.alreadyBlooming", description: "ui.onboarding.bloomIsAlreadyWorkingGoOnTryItOut",
		hints: ["ui.onboarding.openSettingsFromCommandCenter", "linux.onboarding.finishShortcuts", "linux.onboarding.finishUninstall"] }
];

// The real surface shows during its introduction only (Bloom: kind "intro").
function reveal(page) {
	return page.kind === "intro" ? page.anchor : "";
}
