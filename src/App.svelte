<script>
  import { onMount } from 'svelte';
  import Flashcard from './components/Flashcard.svelte';
  import Picker from './components/Picker.svelte';

  let isSignedIn = false;
  let accessToken = null;
  let userProfile = null;
  let tokenExpirationTime = null;
  let selectedSpreadsheetId = null;
  let spreadsheetData = [];
  let currentCardIndex = 0;
  let showDefinition = false;
  let sessionStats = { total: 0, known: 0, unknown: 0 };
  let isLoading = false;
  let studyMode = 'word-to-definition'; // 'word-to-definition' or 'definition-to-word'
  let deckCompleted = false;

  const DISCOVERY_DOC = 'https://sheets.googleapis.com/$discovery/rest?version=v4';
  const SCOPES = 'https://www.googleapis.com/auth/drive https://www.googleapis.com/auth/spreadsheets https://www.googleapis.com/auth/userinfo.profile';
  
  let gis;
  let tokenRefreshInterval;

  function setupChunkLoadingErrorBoundary() {
    let lastReloadTime = 0;
    const BASE_DELAY = 2000; // 2 seconds base delay

    // Reset reload time on successful navigation
    window.addEventListener('load', () => {
      lastReloadTime = 0;
    });

    // Handle asset loading errors (JS/CSS 404s)
    window.addEventListener('error', (event) => {
      const target = event.target || event.srcElement;
      const isAssetError = target && (target.tagName === 'SCRIPT' || target.tagName === 'LINK');
      
      if (isAssetError) {
        const src = target.src || target.href || '';
        const isHashedAsset = /\-[a-zA-Z0-9]{8,}\.(js|css)/.test(src);
        
        if (isHashedAsset) {
          console.warn('Asset loading failed (likely due to deployment):', src);
          reloadWithBackoff();
        }
      }
      
      // Also check for runtime chunk loading errors
      const error = event.error || {};
      const message = event.message || error.message || '';
      
      const isChunkLoadingError = 
        message.includes('Loading chunk') ||
        message.includes('Loading CSS chunk') ||
        message.includes('ChunkLoadError') ||
        message.includes('Failed to import');

      if (isChunkLoadingError) {
        console.warn('Chunk loading error detected:', message);
        reloadWithBackoff();
      }
    });

    // Handle unhandled promise rejections that might be chunk-related
    window.addEventListener('unhandledrejection', (event) => {
      const reason = event.reason || {};
      const message = reason.message || reason.toString() || '';
      
      if (message.includes('Loading chunk') || 
          message.includes('ChunkLoadError') ||
          message.includes('Failed to import') ||
          message.includes('404')) {
        console.warn('Unhandled chunk loading rejection:', message);
        reloadWithBackoff();
      }
    });

    function reloadWithBackoff() {
      const now = Date.now();
      const timeSinceLastReload = now - lastReloadTime;
      
      // Calculate delay with exponential back-off
      const reloadCount = lastReloadTime === 0 ? 0 : Math.floor(timeSinceLastReload / BASE_DELAY) + 1;
      const delay = BASE_DELAY * Math.pow(2, Math.min(reloadCount, 5)); // Cap at 64s max delay
      
      if (timeSinceLastReload >= delay || lastReloadTime === 0) {
        lastReloadTime = now;
        
        console.log(`Reloading page due to asset loading error (delay: ${delay}ms)`);
        
        setTimeout(() => {
          window.location.reload();
        }, delay);
      }
    }
  }

  onMount(async () => {
    if (typeof window !== 'undefined') {
      // Initialize chunk loading error boundary with exponential back-off
      setupChunkLoadingErrorBoundary();
      
      await waitForGoogleAPIs();
      await initializeGapi();
      await initializeGis();
      
      const savedToken = localStorage.getItem('google_access_token');
      const savedTokenExpiration = localStorage.getItem('google_token_expiration');
      const savedProfile = localStorage.getItem('user_profile');
      
      if (savedToken && savedTokenExpiration) {
        const expirationTime = parseInt(savedTokenExpiration);
        const now = Date.now();
        
        // Check if token is still valid (with 5 minute buffer)
        if (now < expirationTime - 5 * 60 * 1000) {
          accessToken = savedToken;
          tokenExpirationTime = expirationTime;
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
          
          // Set up periodic token refresh check
          startTokenRefreshTimer();
          
          // Check for existing mFlashcards file
          await checkForExistingSpreadsheet();
        } else {
          // Token expired, clear it
          console.log('Stored token has expired, clearing...');
          clearAuthData();
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
          
          // Calculate expiration time (tokens typically last 1 hour)
          tokenExpirationTime = Date.now() + (response.expires_in ? response.expires_in * 1000 : 3600 * 1000);
          
          localStorage.setItem('google_access_token', accessToken);
          localStorage.setItem('google_token_expiration', tokenExpirationTime.toString());
          window.gapi.client.setToken({ access_token: accessToken });
          isSignedIn = true;
          startTokenRefreshTimer();
          await getUserProfile();
          await checkForExistingSpreadsheet();
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
      } else if (response.status === 401 || response.status === 403) {
        // Handle auth error
        const error = { status: response.status };
        await handleAuthError(error);
      }
    } catch (error) {
      console.error('Error fetching user profile:', error);
    }
  }

  function clearAuthData() {
    if (tokenRefreshInterval) {
      clearInterval(tokenRefreshInterval);
      tokenRefreshInterval = null;
    }
    localStorage.removeItem('google_access_token');
    localStorage.removeItem('google_token_expiration');
    localStorage.removeItem('user_profile');
    isSignedIn = false;
    accessToken = null;
    tokenExpirationTime = null;
    userProfile = null;
    selectedSpreadsheetId = null;
    spreadsheetData = [];
    resetSession();
  }

  function startTokenRefreshTimer() {
    // Check token every 5 minutes
    if (tokenRefreshInterval) {
      clearInterval(tokenRefreshInterval);
    }
    
    tokenRefreshInterval = setInterval(() => {
      if (isSignedIn && accessToken) {
        refreshTokenIfNeeded();
      }
    }, 5 * 60 * 1000); // Check every 5 minutes
  }

  function signOut() {
    if (accessToken) {
      google.accounts.oauth2.revoke(accessToken);
    }
    clearAuthData();
  }

  async function refreshTokenIfNeeded() {
    if (!accessToken || !tokenExpirationTime) {
      return false;
    }
    
    const now = Date.now();
    const timeUntilExpiry = tokenExpirationTime - now;
    
    // If token expires in less than 5 minutes, refresh it
    if (timeUntilExpiry < 5 * 60 * 1000) {
      console.log('Token expiring soon, requesting refresh...');
      try {
        // Request a new token silently
        if (gis) {
          gis.requestAccessToken({ prompt: '' });
          return true;
        }
      } catch (error) {
        console.error('Failed to refresh token:', error);
        return false;
      }
    }
    
    return true;
  }

  async function handleAuthError(error) {
    console.error('Authentication error:', error);
    
    // Check if it's an auth-related error
    if (error.status === 401 || error.status === 403) {
      console.log('Authentication failed, attempting to refresh token...');
      
      // Try to refresh the token first
      const refreshed = await refreshTokenIfNeeded();
      if (!refreshed) {
        console.log('Token refresh failed, signing out...');
        clearAuthData();
        alert('Your session has expired. Please sign in again.');
        return false;
      }
      return true;
    }
    
    return false;
  }

  async function checkForExistingSpreadsheet() {
    console.log('🔍 Checking for existing mFlashcards spreadsheet...');
    
    // Check token validity before making API call
    const tokenValid = await refreshTokenIfNeeded();
    if (!tokenValid) {
      console.log('❌ Token invalid and refresh failed');
      return;
    }
    
    try {
      // First check if we have the required API access
      if (!window.gapi || !window.gapi.client) {
        console.log('❌ GAPI client not available');
        return;
      }

      // Search for files named "mFlashcards" in Google Drive
      console.log('📋 Searching Google Drive...');
      const response = await window.gapi.client.request({
        path: 'https://www.googleapis.com/drive/v3/files',
        params: {
          q: "name='mFlashcards' and mimeType='application/vnd.google-apps.spreadsheet' and trashed=false",
          fields: 'files(id, name, createdTime)',
        }
      });
      
      console.log('🔍 Drive API response:', response);
      
      if (response.result.files && response.result.files.length > 0) {
        // Found mFlashcards file, load it automatically
        const file = response.result.files[0];
        console.log('✅ Found existing mFlashcards file:', file);
        selectedSpreadsheetId = file.id;
        await loadSpreadsheetData();
      } else {
        console.log('❌ No existing mFlashcards file found in Google Drive');
        console.log('💡 You can create one or select an existing spreadsheet');
      }
    } catch (error) {
      console.error('❌ Error checking for existing spreadsheet:', error);
      console.log('Response status:', error.status);
      console.log('Response body:', error.body);
      
      // Handle authentication errors
      const authHandled = await handleAuthError(error);
      if (authHandled) {
        // Retry the operation
        setTimeout(() => checkForExistingSpreadsheet(), 1000);
        return;
      }
      
      // Try alternative approach - check if it's a permission issue
      if (error.status === 403) {
        console.log('🔐 Permission denied - make sure Drive API is enabled and scopes are correct');
      }
      // Continue normally - user can still select manually
    }
  }

  async function onSpreadsheetSelected(event) {
    selectedSpreadsheetId = event.detail.id;
    await loadSpreadsheetData();
  }

  async function loadSpreadsheetData() {
    if (!selectedSpreadsheetId) return;
    
    // Check token validity before making API call
    const tokenValid = await refreshTokenIfNeeded();
    if (!tokenValid) {
      console.log('❌ Token invalid and refresh failed');
      return;
    }
    
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
      
      // Handle authentication errors
      const authHandled = await handleAuthError(error);
      if (authHandled) {
        // Retry the operation
        setTimeout(() => loadSpreadsheetData(), 1000);
        return;
      }
      
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
    shuffleArray(spreadsheetData);
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
          <div class="mt-4 space-x-4">
            <a href="/privacy-policy.html" class="text-xs text-gray-400 dark:text-gray-500 hover:text-gray-600 dark:hover:text-gray-300 underline">Privacy Policy</a>
            <a href="/terms-of-service.html" class="text-xs text-gray-400 dark:text-gray-500 hover:text-gray-600 dark:hover:text-gray-300 underline">Terms of Service</a>
          </div>
        </div>
      </div>
    {:else}
      {#if sessionStats.total > 0}
        <div class="flex justify-center mb-6">
          <div class="flex items-center gap-4">
            <!-- Split-pill stats display -->
            <div class="flex rounded-full overflow-hidden shadow-lg">
              <div class="bg-green-500 text-white px-4 py-2 font-medium text-sm flex items-center">
                <span class="mr-1">Easy</span>
                <span class="bg-green-600 rounded-full px-2 py-0.5 text-xs font-bold">{sessionStats.known}</span>
              </div>
              <div class="bg-red-500 text-white px-4 py-2 font-medium text-sm flex items-center">
                <span class="mr-1">Hard</span>
                <span class="bg-red-600 rounded-full px-2 py-0.5 text-xs font-bold">{sessionStats.unknown}</span>
              </div>
            </div>
            
            <button
              on:click={resetSession}
              class="bg-orange-500 hover:bg-orange-600 text-white px-3 py-2 rounded-lg text-sm transition-colors duration-200 font-medium"
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