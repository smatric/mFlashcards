# mFlashcards Web App

Visit: [https://smatric.github.io/mFlashcards/](https://smatric.github.io/mFlashcards/) for the live demo.

This is a vibe-coded, Svelte-based flashcard web app that integrates with **Google Sheets API** and **Google Picker API**. It allows you to:
- Authenticate with your Google account (OAuth2).
- Select a spreadsheet from Google Drive.
- Load words and definitions from the selected spreadsheet.
- Review flashcards with **spaced repetition** algorithm (word → definition OR definition → word).
- Track review history and automatically adjust review intervals based on performance.
- Save stats (Easy/Hard responses) back into Google Sheets.
- Tokens are stored in `localStorage` for persistent sessions.

---

## 📑 Google Sheets Structure
By default, "mFlashcards" spreadsheet is loaded. 
If not found, the app will prompt you to select a spreadsheet.

**Spaced Repetition**: The app tracks when each card was last reviewed and calculates the next review date based on your performance. Cards marked as "Easy" will have longer intervals before appearing again, while "Hard" cards will appear more frequently.

You need **two sheets** in the same document:

### `mFlashcards`
| Word       | Definition           | Last Reviewed | Interval |
|------------|----------------------|---------------|----------|
| desist     | to stop              | 2025-09-04    | 3        |
| nascent    | just beginning       | 2025-09-03    | 7        |

- **Last Reviewed**: Date when the flashcard was last studied (YYYY-MM-DD format)
- **Interval**: Number of days until the card should appear again for review

### `StatsData`
| Date       | Easy  | Hard  | Total |
|------------|-------|-------|-------|
| 2025-08-26 | 15    | 5     | 20    |
