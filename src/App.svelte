<script>
  import { onMount } from 'svelte';
  import Flashcard from './components/Flashcard.svelte';
  import Picker from './components/Picker.svelte';

  let isSignedIn = false;
  let accessToken = null;
  let selectedSpreadsheetId = null;
  let spreadsheetData = [];
  let currentCardIndex = 0;
  let showDefinition = false;
  let sessionStats = { total: 0, known: 0, unknown: 0 };
  let isLoading = false;

  const DISCOVERY_DOC = 'https://sheets.googleapis.com/$discovery/rest?version=v4';
  const SCOPES = 'https://www.googleapis.com/auth/drive.file https://www.googleapis.com/auth/spreadsheets';
  
  let gapi, gis;

  onMount(async () => {
    if (typeof window !== 'undefined') {
      await initializeGapi();
      await initializeGis();
      
      const savedToken = localStorage.getItem('google_access_token');
      if (savedToken) {
        accessToken = savedToken;
        gapi.client.setToken({ access_token: accessToken });
        isSignedIn = true;
      }
    }
  });

  async function initializeGapi() {
    await new Promise((resolve) => {
      gapi.load('client', resolve);
    });
    
    await gapi.client.init({
      discoveryDocs: [DISCOVERY_DOC],
    });
  }

  async function initializeGis() {
    gis = google.accounts.oauth2.initTokenClient({
      client_id: import.meta.env.VITE_GOOGLE_CLIENT_ID,
      scope: SCOPES,
      callback: (response) => {
        if (response.access_token) {
          accessToken = response.access_token;
          localStorage.setItem('google_access_token', accessToken);
          gapi.client.setToken({ access_token: accessToken });
          isSignedIn = true;
        }
      },
    });
  }

  function signIn() {
    if (gis) {
      gis.requestAccessToken();
    }
  }

  function signOut() {
    if (accessToken) {
      google.accounts.oauth2.revoke(accessToken);
      localStorage.removeItem('google_access_token');
    }
    isSignedIn = false;
    accessToken = null;
    selectedSpreadsheetId = null;
    spreadsheetData = [];
    resetSession();
  }

  async function onSpreadsheetSelected(event) {
    selectedSpreadsheetId = event.detail.id;
    await loadSpreadsheetData();
  }

  async function loadSpreadsheetData() {
    if (!selectedSpreadsheetId) return;
    
    isLoading = true;
    try {
      const response = await gapi.client.sheets.spreadsheets.values.get({
        spreadsheetId: selectedSpreadsheetId,
        range: 'DeckData!A:B',
      });
      
      const rows = response.result.values || [];
      if (rows.length > 1) {
        spreadsheetData = rows.slice(1).map(([word, definition]) => ({
          word: word || '',
          definition: definition || ''
        })).filter(item => item.word && item.definition);
        
        shuffleArray(spreadsheetData);
        resetSession();
      }
    } catch (error) {
      console.error('Error loading spreadsheet data:', error);
      alert('Error loading spreadsheet data. Make sure you have the correct permissions and the sheet has a "DeckData" tab with Word and Definition columns.');
    } finally {
      isLoading = false;
    }
  }

  function shuffleArray(array) {
    for (let i = array.length - 1; i > 0; i--) {
      const j = Math.floor(Math.random() * (i + 1));
      [array[i], array[j]] = [array[j], array[i]];
    }
  }

  function resetSession() {
    currentCardIndex = 0;
    showDefinition = false;
    sessionStats = { total: 0, known: 0, unknown: 0 };
  }

  function nextCard() {
    showDefinition = false;
    currentCardIndex = (currentCardIndex + 1) % spreadsheetData.length;
  }

  function markKnown() {
    sessionStats.total++;
    sessionStats.known++;
    nextCard();
  }

  function markUnknown() {
    sessionStats.total++;
    sessionStats.unknown++;
    nextCard();
  }

  async function saveStats() {
    if (!selectedSpreadsheetId || sessionStats.total === 0) return;
    
    try {
      const today = new Date().toISOString().split('T')[0];
      const values = [[today, sessionStats.total, sessionStats.known, sessionStats.unknown]];
      
      await gapi.client.sheets.spreadsheets.values.append({
        spreadsheetId: selectedSpreadsheetId,
        range: 'StatsData!A:D',
        valueInputOption: 'USER_ENTERED',
        resource: { values }
      });
      
      alert('Stats saved successfully!');
      resetSession();
    } catch (error) {
      console.error('Error saving stats:', error);
      alert('Error saving stats. Make sure you have a "StatsData" sheet with Date, Total, Known, Unknown columns.');
    }
  }

  $: currentCard = spreadsheetData[currentCardIndex];
  $: hasCards = spreadsheetData.length > 0;
</script>

<main class="min-h-screen bg-gradient-to-br from-blue-50 to-indigo-100 dark:from-gray-900 dark:to-gray-800 p-4">
  <div class="max-w-4xl mx-auto">
    <header class="text-center mb-8">
      <h1 class="text-4xl font-bold text-gray-800 dark:text-white mb-2">
        📚 Svelte Flashcards
      </h1>
      <p class="text-gray-600 dark:text-gray-300">
        Learn with Google Sheets integration
      </p>
    </header>

    {#if !isSignedIn}
      <div class="text-center">
        <div class="bg-white dark:bg-gray-800 rounded-lg shadow-lg p-8 max-w-md mx-auto">
          <h2 class="text-2xl font-semibold mb-4 text-gray-800 dark:text-white">
            Welcome!
          </h2>
          <p class="text-gray-600 dark:text-gray-300 mb-6">
            Sign in with your Google account to access your flashcard spreadsheets.
          </p>
          <button
            on:click={signIn}
            class="bg-blue-500 hover:bg-blue-600 text-white font-medium py-3 px-6 rounded-lg transition-colors duration-200"
          >
            Sign in with Google
          </button>
        </div>
      </div>
    {:else}
      <div class="flex justify-between items-center mb-6">
        <div class="flex items-center gap-4">
          <span class="text-gray-600 dark:text-gray-300">
            Signed in ✅
          </span>
          {#if sessionStats.total > 0}
            <div class="bg-white dark:bg-gray-800 px-4 py-2 rounded-lg shadow">
              <span class="text-sm font-medium text-gray-700 dark:text-gray-300">
                Session: {sessionStats.known}✅ {sessionStats.unknown}❌ / {sessionStats.total}
              </span>
            </div>
          {/if}
        </div>
        <div class="flex gap-2">
          {#if sessionStats.total > 0}
            <button
              on:click={saveStats}
              class="bg-green-500 hover:bg-green-600 text-white px-4 py-2 rounded-lg transition-colors duration-200"
            >
              Save Stats
            </button>
          {/if}
          <button
            on:click={signOut}
            class="bg-red-500 hover:bg-red-600 text-white px-4 py-2 rounded-lg transition-colors duration-200"
          >
            Sign Out
          </button>
        </div>
      </div>

      {#if !selectedSpreadsheetId}
        <Picker on:selected={onSpreadsheetSelected} />
      {:else if isLoading}
        <div class="text-center">
          <div class="bg-white dark:bg-gray-800 rounded-lg shadow-lg p-8">
            <div class="animate-spin rounded-full h-12 w-12 border-b-2 border-blue-500 mx-auto mb-4"></div>
            <p class="text-gray-600 dark:text-gray-300">Loading flashcards...</p>
          </div>
        </div>
      {:else if hasCards}
        <div class="text-center mb-4">
          <span class="text-gray-600 dark:text-gray-300">
            Card {currentCardIndex + 1} of {spreadsheetData.length}
          </span>
        </div>
        
        <Flashcard
          {currentCard}
          bind:showDefinition
          on:known={markKnown}
          on:unknown={markUnknown}
          on:next={nextCard}
        />
        
        <div class="text-center mt-6">
          <button
            on:click={() => selectedSpreadsheetId = null}
            class="text-blue-500 hover:text-blue-600 underline"
          >
            Choose Different Spreadsheet
          </button>
        </div>
      {:else}
        <div class="text-center">
          <div class="bg-white dark:bg-gray-800 rounded-lg shadow-lg p-8">
            <h3 class="text-xl font-semibold mb-4 text-gray-800 dark:text-white">
              No flashcards found
            </h3>
            <p class="text-gray-600 dark:text-gray-300 mb-4">
              Make sure your spreadsheet has a "DeckData" sheet with "Word" and "Definition" columns.
            </p>
            <button
              on:click={() => selectedSpreadsheetId = null}
              class="bg-blue-500 hover:bg-blue-600 text-white px-4 py-2 rounded-lg transition-colors duration-200"
            >
              Choose Different Spreadsheet
            </button>
          </div>
        </div>
      {/if}
    {/if}
  </div>
</main>