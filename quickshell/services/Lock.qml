pragma Singleton

import QtQuick
import Quickshell
import Quickshell.Io
import Quickshell.Services.Pam

// Session lock: the state behind the lock screen, and the PAM conversation
// that ends it.
//
// The lock itself is the compositor's, through ext-session-lock-v1: once
// `locked` goes true every other surface on the system is hidden and only the
// lock surface receives input. That is a real lock rather than a window
// pretending to be one — if this process dies while locked the compositor
// keeps the screen blanked rather than handing the desktop back.
Singleton {
	id: root

	// Whether the session is locked. LockScreen binds the compositor's lock to
	// this, so setting it is what raises and drops the lock.
	property bool locked: false

	// Whether the password field is up. Idle shows the clock, the calendar and
	// any notifications; prompting blurs all of that behind the field.
	property bool prompting: false

	// A PAM exchange is in flight. Input is frozen for its duration: PAM has
	// exactly one conversation at a time, and a second attempt started while
	// the first is still running would answer the wrong prompt.
	property bool authenticating: false

	// Shown under the field. Cleared by the next keystroke.
	property string error: ""

	readonly property string user: Quickshell.env("USER") || "user"

	// Read from the environment rather than asked of the compositor, so this
	// names whatever session happens to be running without the shell knowing
	// anything about it.
	readonly property string session: Quickshell.env("XDG_CURRENT_DESKTOP")
		|| Quickshell.env("XDG_SESSION_DESKTOP")
		|| "Wayland"

	// The typed password, held only for the moment between pressing Enter and
	// PAM asking for it. Cleared as soon as it has been handed over.
	property string pending: ""

	signal failed()

	function lock() {
		if (root.locked) return;
		root.error = "";
		root.prompting = false;
		root.pending = "";
		root.locked = true;
	}

	// Bring the password field up. Called by a click or the first keystroke.
	function prompt() {
		if (!root.locked || root.prompting) return;
		root.error = "";
		root.prompting = true;
	}

	// Escape from the field: back to the clock. Refused mid-authentication,
	// since the exchange would carry on regardless and unlock behind a screen
	// that no longer looks like it is asking for anything.
	function dismiss() {
		if (!root.prompting || root.authenticating) return;
		root.prompting = false;
		root.error = "";
	}

	function submit(password: string) {
		if (root.authenticating) return;
		if (!password) {
			root.error = "Enter your password";
			return;
		}

		root.error = "";
		root.pending = password;
		root.authenticating = true;

		if (!pam.start()) {
			root.authenticating = false;
			root.pending = "";
			root.error = "Could not start authentication";
			root.failed();
		}
	}

	function release() {
		root.locked = false;
		root.prompting = false;
		root.pending = "";
		root.error = "";
	}

	PamContext {
		id: pam

		// swaylock's stack rather than login's: it is plain pam_unix with no
		// pam_loginuid or pam_systemd, which is exactly what an unprivileged
		// process re-checking the current user's own password needs. login's
		// session modules want privileges this shell does not have.
		configDirectory: "/etc/pam.d"
		config: "swaylock"
		user: root.user

		// PAM drives the conversation: it asks, and only then is there
		// somewhere to put the password.
		onPamMessage: {
			console.log("LOCK pamMessage msg=" + JSON.stringify(pam.message)
				+ " responseRequired=" + pam.responseRequired
				+ " pendingLen=" + root.pending.length);
			if (pam.responseRequired) {
				pam.respond(root.pending);
				root.pending = "";
				return;
			}

			// Anything else PAM has to say — an account expiry warning, a
			// fingerprint prompt on machines that have one.
			if (pam.message && pam.messageIsError) root.error = pam.message;
		}

		onCompleted: result => {
			console.log("LOCK completed result=" + result);
			root.authenticating = false;
			root.pending = "";

			if (result === PamResult.Success) {
				root.release();
				return;
			}

			root.error = result === PamResult.MaxTries
				? "Too many attempts"
				: "Incorrect password";
			root.failed();
		}

		onError: err => {
			console.log("LOCK error " + err);
			root.authenticating = false;
			root.pending = "";
			root.error = "Authentication unavailable";
			root.failed();
		}
	}

	// Triggered by the compositor's keybind, which knows nothing about this
	// shell beyond a command to run:
	//
	//   qs ipc call lock lock
	IpcHandler {
		target: "lock"

		function lock(): void {
			root.lock();
		}

		function auth(password: string): void {
			console.log("LOCK auth() called, authenticating=" + root.authenticating);
			root.submit(password);
			console.log("LOCK after submit, authenticating=" + root.authenticating);
		}

		function isLocked(): bool {
			return root.locked;
		}
	}
}
