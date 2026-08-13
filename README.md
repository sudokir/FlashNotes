# FlashNotes

FlashNotes is a native macOS student productivity app intended to combine basic features from popular flashcard and note-taking software (Anki, Obsidian, etc.) into one simple, lightweight program. It was built with SwiftUI, SwiftData, TextKit, and AppKit. A web version with synced changes is currently in development.

## Open and run

1. Open `Flashnotes.xcodeproj` in Xcode.
2. Select the **Flashnotes** scheme and **My Mac** destination.
3. Press **Command-R** to run.
4. Press **Command-U** to run the unit tests.

## Library features

- Use the toolbar search button or **Shift-Command-F** to search folders, notes, decks, cards, and tags.
- Open the command palette with **Shift-Command-P**.
- Navigate with the toolbar arrows or **Command-[** and **Command-]**. Breadcrumbs above the content show your current location.
- Right-click folders to favorite them or choose a color and symbol. Right-click notes and decks to favorite or tag them.
- To remove a favorite, right-click it anywhere in the sidebar and choose **Remove from Favorites**.
- Each folder has its own sorting controls. The sidebar also provides Favorites, Recent, Expand All, Collapse All, and Trash.
- Normal deletion moves content to Trash without a warning. Trash supports restoring content or permanently deleting it.

## Notes and flashcards

- A note's toolbar can assign it to a deck. After assignment, a complete line such as `Question :: Answer` creates one card whose front is `Question` and back is `Answer`. Identical pairs are not generated twice.
- The note status bar shows word count, character count, and estimated reading time.
- Notes can be exported from their toolbar as Markdown, plain text, or PDF.

## Keyboard shortcuts

Open **FlashNotes → Settings…**, then scroll below Appearance to change or disable shortcuts for navigation, library actions, note/deck assignment, export, review, tab management, and Markdown editing. A shortcut can be set to **None**; Settings warns when a combination is assigned more than once and can restore every default.

## Install as a standalone app

Release bundles are intentionally excluded from source control. Build or archive the **Flashnotes** scheme in Xcode, then move the resulting `FlashNotes.app` into Applications. Existing local development workspaces may also keep a signed build under `Dist/FlashNotes.app`; that folder is not uploaded to GitHub. Your existing library is retained because development and release builds use the same bundle identifier and SwiftData store.

If macOS asks for confirmation the first time, Control-click the app in Applications, choose **Open**, then confirm **Open**.

User content is stored by SwiftData in the app container. Image attachments are resized and stored under the app's Application Support `Flashnotes/Attachments` directory.

Version 1.2 performs an additive data migration and preserves existing content. Before opening the upgraded data model for the first time, it also creates a one-time recoverable backup under `~/Library/Application Support/Flashnotes/Backups/Before-Library-Features/`.
