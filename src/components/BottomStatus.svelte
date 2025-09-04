<script>
  export let userProfile;
  export let signOut;
</script>

<!-- Bottom status -->
<div class="text-center mt-4 pt-4 border-t border-gray-200 dark:border-gray-700">
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