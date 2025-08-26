# Svelte Flashcards Web App

This is a Svelte-based flashcard web app that integrates with **Google Sheets API** and **Google Picker API**. It allows you to:
- Authenticate with your Google account (OAuth2).
- Select a spreadsheet from Google Drive.
- Load words and definitions from the selected spreadsheet.
- Review flashcards (word → definition OR definition → word).
- Save stats (reviewed, known, unknown) back into Google Sheets.

---

## 🚀 Features
- Built with **Svelte** + **TailwindCSS**.
- Dark/Light theme support (follows system preference).
- Flashcards shuffle each session.
- Tracks known/unknown counts.
- Stats written back to Google Sheets.
- Authentication via **Google Identity Services**.
- Google Picker integration for selecting spreadsheets.

---

## 📂 Project Structure
```
src/
├── App.svelte          # Main app logic
├── main.js             # Entry point
└── components/
    ├── Flashcard.svelte # Card flipping logic
    └── Picker.svelte    # Google Picker integration

public/
└── index.html
```

---

## 🛠️ Setup Instructions

### 1. Prerequisites
- Node.js (>= 18)
- npm or pnpm
- A Google account (Gmail).

### 2. Clone the Repo
```bash
git clone https://github.com/YOUR-USERNAME/svelte-flashcards.git
cd svelte-flashcards
npm install
```

### 3. Google Cloud Setup
1. Go to [Google Cloud Console](https://console.cloud.google.com/).
2. Create a **new project** (e.g., `FlashcardsApp`).
3. Enable APIs:
   - Google Sheets API
   - Google Drive API
   - Google Picker API
4. Go to **APIs & Services → Credentials**:
   - Create **OAuth Client ID** → Type: `Web Application`.
   - Add authorized origins:
     - `http://localhost:5173` (for local dev)
     - `https://YOUR_USERNAME.github.io` (for GitHub Pages)
   - Copy the **Client ID**.
5. Configure **OAuth Consent Screen**:
   - User type: `External`
   - Add yourself as a test user (or publish for public use).
   - Scopes needed:
     - `https://www.googleapis.com/auth/drive.file`
     - `https://www.googleapis.com/auth/spreadsheets`

### 4. Environment Variables
Create a `.env` file in project root:
```bash
VITE_GOOGLE_CLIENT_ID=your-oauth-client-id
```

### 5. Run Locally
```bash
npm run dev
```
Visit: [http://localhost:5173](http://localhost:5173)

### 6. Build & Deploy
For GitHub Pages:
```bash
npm run build
```
Push the contents of `dist/` to your GitHub Pages branch (usually `gh-pages`).

For Netlify or Vercel:
- Just connect the repo and set `npm run build` as build command.

---

## 📑 Google Sheets Structure
You need **two sheets** in the same document:

### `DeckData`
| Word       | Definition           |
|------------|----------------------|
| desist     | to stop              |
| nascent    | just beginning       |

### `StatsData`
| Date       | Total | Known | Unknown |
|------------|-------|-------|---------|
| 2025-08-26 | 20    | 15    | 5       |

---

## 📌 Notes
- Tokens are stored in `localStorage` for persistent sessions.
- You can revoke access from [Google Account Permissions](https://myaccount.google.com/permissions).
- Only you need to configure Google Cloud. Users just log in with their Google account.

---

## ✅ Next Steps
- Implement flashcard animations using Svelte transitions.
- Improve stats tracking (per word, spaced repetition).
- Add multiple deck support.

---

**Author:** Your Name  
**License:** MIT
