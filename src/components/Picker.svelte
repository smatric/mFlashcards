<script>
  import { createEventDispatcher } from 'svelte';
  
  const dispatch = createEventDispatcher();
  
  let pickerApiLoaded = false;
  let oauthToken;

  // Load Picker API
  function loadPicker() {
    gapi.load('picker', {
      callback: onPickerApiLoad,
    });
  }

  function onPickerApiLoad() {
    pickerApiLoaded = true;
  }

  function getOAuthToken() {
    return gapi.client.getToken()?.access_token;
  }

  function createPicker() {
    if (pickerApiLoaded && gapi.client.getToken()) {
      const token = getOAuthToken();
      const view = new google.picker.View(google.picker.ViewId.SPREADSHEETS);
      view.setMimeTypes("application/vnd.google-apps.spreadsheet");
      
      const picker = new google.picker.PickerBuilder()
        .enableFeature(google.picker.Feature.SUPPORT_DRIVES)
        .setDeveloperKey(import.meta.env.VITE_GOOGLE_API_KEY || '')
        .setOAuthToken(token)
        .addView(view)
        .addView(new google.picker.DocsUploadView())
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
  if (typeof window !== 'undefined' && window.gapi) {
    loadPicker();
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
      Make sure your spreadsheet has a "DeckData" sheet with "Word" and "Definition" columns, 
      and optionally a "StatsData" sheet for saving progress.
    </p>
    <button
      on:click={createPicker}
      disabled={!pickerApiLoaded}
      class="bg-green-500 hover:bg-green-600 disabled:bg-gray-400 disabled:cursor-not-allowed text-white font-medium py-3 px-6 rounded-lg transition-colors duration-200"
    >
      {#if !pickerApiLoaded}
        Loading Picker...
      {:else}
        📁 Browse Google Drive
      {/if}
    </button>
  </div>
</div>