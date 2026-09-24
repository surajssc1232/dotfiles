//@ pragma UseQApplication

import QtQml
import Quickshell
import qs.modules

ShellRoot {
	// Re-read the config whenever a file under it is saved, rather than only
	// at startup. Without this an edit sits inert until "Reload the shell" is
	// run by hand, which is a long way to chase a typo. A save that lands on a
	// half-written file still only costs a failed reload: the running config
	// stays up and the error arrives as a popup.
	Component.onCompleted: Quickshell.watchFiles = true

	// Painted under everything else, one per monitor.
	Variants {
		model: Quickshell.screens

		WallpaperLayer {}
	}

	// One bar per connected monitor, created and destroyed as they come and go.
	Variants {
		model: Quickshell.screens

		Bar {}
	}

	// Toast stack, also per monitor.
	Variants {
		model: Quickshell.screens

		NotificationPopups {}
	}

	// Capture surface, mapped only while a screenshot is being taken.
	Variants {
		model: Quickshell.screens

		ScreenshotOverlay {}
	}

	// Application launcher, mapped only while open.
	Variants {
		model: Quickshell.screens

		Launcher {}
	}

	// Alt-Tab overlay, mapped only while switching.
	Variants {
		model: Quickshell.screens

		Switcher {}
	}

	// Asked once a recording finishes.
	Variants {
		model: Quickshell.screens

		RecorderPrompt {}
	}

	// Session lock. Not per-monitor: a lock owns every output at once and
	// makes its own surface for each, including any plugged in while locked.
	LockScreen {}
}
