<script>
  import { createEventDispatcher } from 'svelte';
  
  const dispatch = createEventDispatcher();
  
  let pickerApiLoaded = false;
  let isInitializing = true;

  // Wait for Google APIs and load Picker
  async function initializePicker() {
    try {
      await waitForGoogleAPIs();
      await loadPicker();
    } catch (error) {
      console.error('Failed to initialize picker:', error);
    } finally {
      isInitializing = false;
    }
  }

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

  function loadPicker() {
    return new Promise((resolve, reject) => {
      window.gapi.load('picker', {
        callback: () => {
          pickerApiLoaded = true;
          resolve();
        },
        onerror: reject
      });
    });
  }

  function getOAuthToken() {
    return window.gapi.client.getToken()?.access_token;
  }

  function createPicker() {
    if (pickerApiLoaded && window.gapi.client.getToken()) {
      const token = getOAuthToken();
      const view = new google.picker.View(google.picker.ViewId.SPREADSHEETS);
      view.setMimeTypes("application/vnd.google-apps.spreadsheet");
      
      const picker = new google.picker.PickerBuilder()
        .enableFeature(google.picker.Feature.SUPPORT_DRIVES)
        .setOAuthToken(token)
        .addView(view)
        .setCallback(pickerCallback)
        .build();
      
      picker.setVisible(true);
    }
  }

  function pickerCallback(data) {
    if (data.action === google.picker.Action.PICKED) {
      const fileId = data.docs[0].id;
      const fileName = data.docs[0].name;
      dispatch('selected', { id: fileId, name: fileName });
    }
  }

  // Initialize picker when component mounts
  if (typeof window !== 'undefined') {
    initializePicker();
  }
</script>

<div class="text-center">
  <div class="bg-white dark:bg-gray-800 rounded-lg shadow-lg p-8 max-w-md mx-auto">
    <h2 class="text-2xl font-semibold mb-4 text-gray-800 dark:text-white">
      📊 Select Spreadsheet
    </h2>
    <p class="text-gray-600 dark:text-gray-300 mb-6">
      Choose a Google Sheets document containing your flashcard data.
    </p>
    <p class="text-sm text-gray-500 dark:text-gray-400 mb-6">
      Make sure your spreadsheet has a "mFlashcards" sheet with "Word" and "Definition" columns,
      and optionally a "StatsData" sheet for saving progress.
    </p>
    <button
      on:click={createPicker}
      disabled={!pickerApiLoaded || isInitializing}
      class="bg-green-500 hover:bg-green-600 disabled:bg-gray-400 disabled:cursor-not-allowed text-white font-medium py-3 px-6 rounded-lg transition-colors duration-200"
    >
      {#if isInitializing}
        Loading Picker...
      {:else if !pickerApiLoaded}
        Picker Failed to Load
      {:else}
        📁 Browse Google Drive
      {/if}
    </button>
  </div>
</div>