# mFlashcards Web App

Visit: [https://smatric.github.io/mFlashcards/](https://smatric.github.io/mFlashcards/) for the live demo.

This is a vibe-coded, Svelte-based flashcard web app that integrates with **Google Sheets API** and **Google Picker API**. It allows you to:
- Authenticate with your Google account (OAuth2).
- Select a spreadsheet from Google Drive.
- Load words and definitions from the selected spreadsheet.
- Review flashcards (word → definition OR definition → word).
- Save stats (reviewed, known, unknown) back into Google Sheets.
- Tokens are stored in `localStorage` for persistent sessions.

---

### 1. Run Locally
```bash
npm run dev
```
Visit: [http://localhost:3000](http://localhost:3000)

### 2. Build & Deploy
For GitHub Pages:
```bash
npm run build
```

---

## 📑 Google Sheets Structure
Be default "mFlashcards" spreadsheet is loaded. If not found, the app will prompt you to select a spreadsheet.

You need **two sheets** in the same document:

### `mFlashcards`
| Word       | Definition           |
|------------|----------------------|
| desist     | to stop              |
| nascent    | just beginning       |

### `StatsData`
| Date       | Total | Known | Unknown |
|------------|-------|-------|---------|
| 2025-08-26 | 20    | 15    | 5       |
