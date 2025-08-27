<script>
  import { onMount } from 'svelte';
  import Flashcard from './components/Flashcard.svelte';
  import Picker from './components/Picker.svelte';

  let isSignedIn = false;
  let accessToken = null;
  let userProfile = null;
  let selectedSpreadsheetId = null;
  let spreadsheetData = [];
  let currentCardIndex = 0;
  let showDefinition = false;
  let sessionStats = { total: 0, known: 0, unknown: 0 };
  let isLoading = false;
  let studyMode = 'word-to-definition'; // 'word-to-definition' or 'definition-to-word'
  let deckCompleted = false;

  const DISCOVERY_DOC = 'https://sheets.googleapis.com/$discovery/rest?version=v4';
  const SCOPES = 'https://www.googleapis.com/auth/drive.file https://www.googleapis.com/auth/spreadsheets https://www.googleapis.com/auth/userinfo.profile';
  
  let gis;

  onMount(async () => {
    if (typeof window !== 'undefined') {
      await waitForGoogleAPIs();
      await initializeGapi();
      await initializeGis();
      
      const savedToken = localStorage.getItem('google_access_token');
      const savedProfile = localStorage.getItem('user_profile');
      if (savedToken) {
        accessToken = savedToken;
        window.gapi.client.setToken({ access_token: accessToken });
        isSignedIn = true;
        if (savedProfile) {
          try {
            userProfile = JSON.parse(savedProfile);
          } catch (error) {
            console.error('Error parsing saved profile:', error);
            await getUserProfile();
          }
        } else {
          await getUserProfile();
        }
      }
    }
  });

  function waitForGoogleAPIs() {
    return new Promise((resolve) => {
      const checkAPIs = () => {
        if (typeof window.gapi !== 'undefined' && typeof window.google !== 'undefined') {
          resolve();
        } else {
          setTimeout(checkAPIs, 100);
        }
      };
      checkAPIs();
    });
  }

  async function initializeGapi() {
    await new Promise((resolve) => {
      window.gapi.load('client', resolve);
    });
    
    await window.gapi.client.init({
      discoveryDocs: [DISCOVERY_DOC],
    });
  }

  async function initializeGis() {
    gis = google.accounts.oauth2.initTokenClient({
      client_id: import.meta.env.VITE_GOOGLE_CLIENT_ID,
      scope: SCOPES,
      callback: async (response) => {
        if (response.access_token) {
          accessToken = response.access_token;
          localStorage.setItem('google_access_token', accessToken);
          window.gapi.client.setToken({ access_token: accessToken });
          isSignedIn = true;
          await getUserProfile();
        }
      },
    });
  }

  function signIn() {
    if (gis) {
      gis.requestAccessToken();
    }
  }

  async function getUserProfile() {
    try {
      const response = await fetch('https://www.googleapis.com/oauth2/v2/userinfo', {
        headers: {
          'Authorization': `Bearer ${accessToken}`
        }
      });
      if (response.ok) {
        userProfile = await response.json();
        localStorage.setItem('user_profile', JSON.stringify(userProfile));
      }
    } catch (error) {
      console.error('Error fetching user profile:', error);
    }
  }

  function signOut() {
    if (accessToken) {
      google.accounts.oauth2.revoke(accessToken);
      localStorage.removeItem('google_access_token');
      localStorage.removeItem('user_profile');
    }
    isSignedIn = false;
    accessToken = null;
    userProfile = null;
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
      // First, get spreadsheet metadata to check available sheets
      const metadataResponse = await window.gapi.client.sheets.spreadsheets.get({
        spreadsheetId: selectedSpreadsheetId,
      });
      
      const sheets = metadataResponse.result.sheets || [];
      const sheetNames = sheets.map(sheet => sheet.properties.title);
      console.log('Available sheets:', sheetNames);
      
      // Try to find mFlashcards sheet
      if (!sheetNames.includes('mFlashcards')) {
        throw new Error(`mFlashcards sheet not found. Available sheets: ${sheetNames.join(', ')}`);
      }
      
      const response = await window.gapi.client.sheets.spreadsheets.values.get({
        spreadsheetId: selectedSpreadsheetId,
        range: 'mFlashcards!A:B',
      });
      
      const rows = response.result.values || [];
      console.log('Raw data from sheet:', rows);
      
      if (rows.length === 0) {
        throw new Error('mFlashcards sheet is empty');
      }
      
      if (rows.length === 1) {
        throw new Error('mFlashcards sheet only has headers. Add some flashcard data below the headers.');
      }
      
      // Skip header row and process data
      spreadsheetData = rows.slice(1).map(([word, definition]) => ({
        word: word || '',
        definition: definition || ''
      })).filter(item => item.word && item.definition);
      
      if (spreadsheetData.length === 0) {
        throw new Error('No valid flashcard pairs found. Make sure both Word and Definition columns have data.');
      }
      
      shuffleArray(spreadsheetData);
      resetSession();
      console.log('Loaded flashcards:', spreadsheetData);
      
    } catch (error) {
      console.error('Error loading spreadsheet data:', error);
      let errorMessage = 'Error loading spreadsheet data: ';
      
      if (error.status === 403) {
        errorMessage += 'Permission denied. Make sure the spreadsheet is accessible and you have edit permissions.';
      } else if (error.status === 404) {
        errorMessage += 'Spreadsheet not found. Make sure you selected the correct file.';
      } else if (error.message) {
        errorMessage += error.message;
      } else {
        errorMessage += 'Unknown error occurred.';
      }
      
      alert(errorMessage);
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
    deckCompleted = false;
  }

  function toggleStudyMode() {
    studyMode = studyMode === 'word-to-definition' ? 'definition-to-word' : 'word-to-definition';
    showDefinition = false; // Reset card flip when changing mode
  }

  function nextCard() {
    showDefinition = false;
    currentCardIndex = currentCardIndex + 1;
    
    // Check if we've reached the end of the deck
    if (currentCardIndex >= spreadsheetData.length) {
      deckCompleted = true;
    }
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

  function restartDeck() {
    shuffleArray(spreadsheetData);
    resetSession();
  }

  async function saveStats() {
    if (!selectedSpreadsheetId || sessionStats.total === 0) return;
    
    try {
      const today = new Date().toISOString().split('T')[0];
      const values = [[today, sessionStats.total, sessionStats.known, sessionStats.unknown]];
      
      await window.gapi.client.sheets.spreadsheets.values.append({
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
        mFlashcards
      </h1>
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
      {#if sessionStats.total > 0}
        <div class="flex justify-center mb-6">
          <div class="bg-white dark:bg-gray-800 px-4 py-2 rounded-lg shadow">
            <span class="text-sm font-medium text-gray-700 dark:text-gray-300">
              {sessionStats.known} ✅ {sessionStats.unknown} ❌ / {sessionStats.total}
            </span>
            <button
              on:click={resetSession}
              class="ml-4 bg-orange-500 hover:bg-orange-600 text-white px-3 py-1 rounded text-sm transition-colors duration-200"
            >
              Reset Deck
            </button>
          </div>
        </div>
      {/if}

      {#if !selectedSpreadsheetId}
        <Picker on:selected={onSpreadsheetSelected} />
      {:else if isLoading}
        <div class="text-center">
          <div class="bg-white dark:bg-gray-800 rounded-lg shadow-lg p-8">
            <div class="animate-spin rounded-full h-12 w-12 border-b-2 border-blue-500 mx-auto mb-4"></div>
            <p class="text-gray-600 dark:text-gray-300">Loading flashcards...</p>
          </div>
        </div>
      {:else if hasCards && !deckCompleted}
        <div class="flex justify-between items-center mb-4">
          <span class="text-gray-600 dark:text-gray-300">
            Card {currentCardIndex + 1} of {spreadsheetData.length}
          </span>
          
          <!-- Study Mode Toggle -->
          <div class="flex items-center gap-3">
            <span class="text-sm text-gray-600 dark:text-gray-300 hidden sm:inline">Study Mode:</span>
            <button
              on:click={toggleStudyMode}
              class="relative inline-flex h-6 w-11 items-center rounded-full transition-colors duration-200 focus:outline-none focus:ring-2 focus:ring-blue-500 focus:ring-offset-2 {studyMode === 'word-to-definition' ? 'bg-blue-500' : 'bg-gray-400'}"
            >
              <span class="inline-block h-4 w-4 transform rounded-full bg-white transition-transform duration-200 {studyMode === 'word-to-definition' ? 'translate-x-6' : 'translate-x-1'}"></span>
            </button>
            <span class="text-sm text-gray-600 dark:text-gray-300 min-w-0">
              {studyMode === 'word-to-definition' ? 'Word → Definition' : 'Definition → Word'}
            </span>
          </div>
        </div>
        
        <Flashcard
          {currentCard}
          {studyMode}
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
        
        <!-- Bottom status -->
        <div class="text-center mt-8 pt-4 border-t border-gray-200 dark:border-gray-700">
          <div class="flex justify-center items-center gap-4">
            <span class="text-gray-600 dark:text-gray-300 text-sm">
{userProfile ? `Signed in as ${userProfile.name}` : 'Signed in'}
            </span>
            <button
              on:click={signOut}
              class="bg-red-500 hover:bg-red-600 text-white px-4 py-2 rounded-lg transition-colors duration-200 text-sm"
            >
              Sign Out
            </button>
          </div>
        </div>
      {:else if deckCompleted}
        <!-- Deck Completion Screen -->
        <div class="text-center">
          <div class="bg-white dark:bg-gray-800 rounded-lg shadow-lg p-8 max-w-md mx-auto">
            <h2 class="text-3xl font-bold mb-4 text-gray-800 dark:text-white">
              🎉 Deck Complete!
            </h2>
            <p class="text-gray-600 dark:text-gray-300 mb-6">
              You've finished all {spreadsheetData.length} cards in this deck.
            </p>
            
            <!-- Session Stats -->
            <div class="bg-gray-50 dark:bg-gray-700 rounded-lg p-6 mb-6">
              <h3 class="text-lg font-semibold mb-4 text-gray-800 dark:text-white">Session Stats</h3>
              <div class="grid grid-cols-3 gap-4 text-center">
                <div>
                  <div class="text-2xl font-bold text-blue-600 dark:text-blue-400">{sessionStats.total}</div>
                  <div class="text-sm text-gray-600 dark:text-gray-300">Total</div>
                </div>
                <div>
                  <div class="text-2xl font-bold text-green-600 dark:text-green-400">{sessionStats.known}</div>
                  <div class="text-sm text-gray-600 dark:text-gray-300">Known</div>
                </div>
                <div>
                  <div class="text-2xl font-bold text-red-600 dark:text-red-400">{sessionStats.unknown}</div>
                  <div class="text-sm text-gray-600 dark:text-gray-300">Unknown</div>
                </div>
              </div>
              
              {#if sessionStats.total > 0}
                <div class="mt-4">
                  <div class="text-sm text-gray-600 dark:text-gray-300 mb-2">
                    Accuracy: {Math.round((sessionStats.known / sessionStats.total) * 100)}%
                  </div>
                  <div class="w-full bg-gray-200 dark:bg-gray-600 rounded-full h-2">
                    <div 
                      class="bg-green-500 h-2 rounded-full transition-all duration-300" 
                      style="width: {(sessionStats.known / sessionStats.total) * 100}%"
                    ></div>
                  </div>
                </div>
              {/if}
            </div>
            
            <!-- Action Buttons -->
            <div class="flex justify-center">
              <button
                on:click={restartDeck}
                class="bg-blue-500 hover:bg-blue-600 text-white font-medium px-6 py-3 rounded-lg transition-colors duration-200"
              >
                🔄 Study Again
              </button>
            </div>
            
            <div class="mt-6">
              <button
                on:click={() => selectedSpreadsheetId = null}
                class="text-blue-500 hover:text-blue-600 underline"
              >
                Choose Different Spreadsheet
              </button>
            </div>
          </div>
          
          <!-- Bottom status -->
          <div class="text-center mt-8 pt-4 border-t border-gray-200 dark:border-gray-700">
            <div class="flex justify-center items-center gap-4">
              <span class="text-gray-600 dark:text-gray-300 text-sm">
  {userProfile ? `Signed in as ${userProfile.name}` : 'Signed in'}
              </span>
              <button
                on:click={signOut}
                class="bg-red-500 hover:bg-red-600 text-white px-4 py-2 rounded-lg transition-colors duration-200 text-sm"
              >
                Sign Out
              </button>
            </div>
          </div>
        </div>
      {:else}
        <div class="text-center">
          <div class="bg-white dark:bg-gray-800 rounded-lg shadow-lg p-8">
            <h3 class="text-xl font-semibold mb-4 text-gray-800 dark:text-white">
              No flashcards found
            </h3>
            <p class="text-gray-600 dark:text-gray-300 mb-4">
              Make sure your spreadsheet has a "mFlashcards" sheet with "Word" and "Definition" columns.
            </p>
            <button
              on:click={() => selectedSpreadsheetId = null}
              class="bg-blue-500 hover:bg-blue-600 text-white px-4 py-2 rounded-lg transition-colors duration-200"
            >
              Choose Different Spreadsheet
            </button>
          </div>
          
          <!-- Bottom status -->
          <div class="text-center mt-8 pt-4 border-t border-gray-200 dark:border-gray-700">
            <div class="flex justify-center items-center gap-4">
              <span class="text-gray-600 dark:text-gray-300 text-sm">
  {userProfile ? `Signed in as ${userProfile.name}` : 'Signed in'}
              </span>
              <button
                on:click={signOut}
                class="bg-red-500 hover:bg-red-600 text-white px-4 py-2 rounded-lg transition-colors duration-200 text-sm"
              >
                Sign Out
              </button>
            </div>
          </div>
        </div>
      {/if}
      
      <!-- Bottom status for picker and loading screens -->
      {#if !hasCards || isLoading}
        <div class="text-center mt-8 pt-4 border-t border-gray-200 dark:border-gray-700">
          <div class="flex justify-center items-center gap-4">
            <span class="text-gray-600 dark:text-gray-300 text-sm">
{userProfile ? `Signed in as ${userProfile.name}` : 'Signed in'}
            </span>
            <button
              on:click={signOut}
              class="bg-red-500 hover:bg-red-600 text-white px-4 py-2 rounded-lg transition-colors duration-200 text-sm"
            >
              Sign Out
            </button>
          </div>
        </div>
      {/if}
    {/if}
  </div>
</main>