<script>
  import { createEventDispatcher } from 'svelte';
  import { flip } from 'svelte/animate';
  import { scale } from 'svelte/transition';
  
  const dispatch = createEventDispatcher();
  
  export let currentCard;
  export let studyMode = 'word-to-definition';
  export let showDefinition = false;
  
  function toggleCard() {
    showDefinition = !showDefinition;
  }
  
  function handleKnown() {
    dispatch('known');
  }
  
  function handleUnknown() {
    dispatch('unknown');
  }
  
  function handleNext() {
    dispatch('next');
  }

  // Determine what to show based on study mode
  $: showWordFirst = studyMode === 'word-to-definition';
</script>

{#if currentCard}
  <div class="max-w-2xl mx-auto">
    <!-- Flashcard -->
    <div class="relative perspective-1000 mb-8">
      <div 
        class="flashcard-container cursor-pointer transform-style-preserve-3d transition-transform duration-300 {showDefinition ? 'rotate-y-180' : ''}"
        on:click={toggleCard}
        on:keydown={(e) => e.key === ' ' && toggleCard()}
        role="button"
        tabindex="0"
      >
        <!-- Front of card -->
        <div class="flashcard-face flashcard-front bg-white dark:bg-gray-800 shadow-xl rounded-xl p-8 min-h-[300px] flex items-center justify-center">
          <div class="text-center">
            <div class="text-sm text-gray-500 dark:text-gray-400 mb-2">
              {showWordFirst ? 'Word' : 'Definition'}
            </div>
            <div class="text-2xl md:text-3xl font-semibold text-gray-800 dark:text-white break-words">
              {showWordFirst ? currentCard.word : currentCard.definition}
            </div>
            <div class="mt-6 text-sm text-gray-500 dark:text-gray-400">
              Click to reveal {showWordFirst ? 'definition' : 'word'}
            </div>
          </div>
        </div>
        
        <!-- Back of card -->
        <div class="flashcard-face flashcard-back bg-blue-50 dark:bg-blue-900 shadow-xl rounded-xl p-8 min-h-[300px] flex items-center justify-center">
          <div class="text-center">
            <div class="text-sm text-gray-600 dark:text-gray-300 mb-2">
              {showWordFirst ? 'Definition' : 'Word'}
            </div>
            <div class="text-2xl md:text-3xl font-semibold text-blue-800 dark:text-blue-200 break-words">
              {showWordFirst ? currentCard.definition : currentCard.word}
            </div>
          </div>
        </div>
      </div>
    </div>
    
    <!-- Action buttons (always visible) -->
    <div class="flex gap-6 justify-center mt-6">
      <button
        on:click={handleUnknown}
        class="bg-red-500 hover:bg-red-600 text-white font-medium px-8 py-3 rounded-lg transition-colors duration-200 flex items-center gap-2"
      >
        <span>❌</span>
        Don't Know
      </button>
      
      <button
        on:click={handleKnown}
        class="bg-green-500 hover:bg-green-600 text-white font-medium px-8 py-3 rounded-lg transition-colors duration-200 flex items-center gap-2"
      >
        <span>✅</span>
        I Know This
      </button>
    </div>
  </div>
{/if}

<style>
  .perspective-1000 {
    perspective: 1000px;
  }
  
  .transform-style-preserve-3d {
    transform-style: preserve-3d;
  }
  
  .rotate-y-180 {
    transform: rotateY(180deg);
  }
  
  .flashcard-container {
    position: relative;
    width: 100%;
    height: 300px;
  }
  
  .flashcard-face {
    position: absolute;
    width: 100%;
    height: 100%;
    backface-visibility: hidden;
    border: 2px solid transparent;
    transition: border-color 0.2s;
  }
  
  .flashcard-container:hover .flashcard-face {
    border-color: #3b82f6;
  }
  
  .flashcard-back {
    transform: rotateY(180deg);
  }
</style>