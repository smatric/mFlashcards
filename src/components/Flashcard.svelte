<script>
  import { createEventDispatcher } from 'svelte';
  import { flip } from 'svelte/animate';
  import { scale } from 'svelte/transition';
  
  const dispatch = createEventDispatcher();
  
  export let currentCard;
  export let studyMode = 'word-to-definition';
  export let showDefinition = false;
  
  let cardElement;
  let isDragging = false;
  let startX = 0;
  let currentX = 0;
  let translateX = 0;
  let isAnimating = false;
  
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

  // Touch/Mouse event handlers for swiping
  function handleStart(e) {
    if (isAnimating) return;
    isDragging = true;
    startX = e.type === 'mousedown' ? e.clientX : e.touches[0].clientX;
    currentX = startX;
    translateX = 0;
  }

  function handleMove(e) {
    if (!isDragging || isAnimating) return;
    e.preventDefault();
    currentX = e.type === 'mousemove' ? e.clientX : e.touches[0].clientX;
    translateX = currentX - startX;
    
    // Limit the drag distance
    translateX = Math.max(-200, Math.min(200, translateX));
  }

  function handleEnd() {
    if (!isDragging || isAnimating) return;
    isDragging = false;
    isAnimating = true;
    
    const threshold = 80;
    
    if (translateX > threshold) {
      // Swipe right - "I Know This"
      translateX = 300;
      setTimeout(() => {
        handleKnown();
        resetCard();
      }, 200);
    } else if (translateX < -threshold) {
      // Swipe left - "Don't Know"
      translateX = -300;
      setTimeout(() => {
        handleUnknown();
        resetCard();
      }, 200);
    } else {
      // Snap back to center
      translateX = 0;
      setTimeout(() => {
        isAnimating = false;
      }, 200);
    }
  }

  function resetCard() {
    translateX = 0;
    isAnimating = false;
  }

  // Determine what to show based on study mode
  $: showWordFirst = studyMode === 'word-to-definition';
  
  // Calculate opacity based on swipe distance
  $: swipeOpacity = Math.abs(translateX) / 200;
  $: swipeDirection = translateX > 0 ? 'right' : 'left';
</script>

{#if currentCard}
  <div class="max-w-2xl mx-auto">
    <!-- Flashcard -->
    <div class="relative perspective-1000 mb-8">
      <!-- Swipe indicators -->
      {#if isDragging && Math.abs(translateX) > 20}
        <div class="absolute top-1/2 left-4 transform -translate-y-1/2 z-20 pointer-events-none transition-opacity duration-200" 
             style="opacity: {swipeDirection === 'left' ? swipeOpacity : 0}">
          <div class="bg-red-500 text-white px-3 py-1 rounded-full text-sm font-medium">
            Don't Know
          </div>
        </div>
        <div class="absolute top-1/2 right-4 transform -translate-y-1/2 z-20 pointer-events-none transition-opacity duration-200"
             style="opacity: {swipeDirection === 'right' ? swipeOpacity : 0}">
          <div class="bg-green-500 text-white px-3 py-1 rounded-full text-sm font-medium">
            I Know This
          </div>
        </div>
      {/if}
      
      <div 
        bind:this={cardElement}
        class="flashcard-container cursor-pointer transform-style-preserve-3d transition-all duration-300 {showDefinition ? 'rotate-y-180' : ''} {isAnimating ? 'transition-transform' : ''}"
        style="transform: translateX({translateX}px) {showDefinition ? 'rotateY(180deg)' : ''}"
        on:click={toggleCard}
        on:keydown={(e) => e.key === ' ' && toggleCard()}
        on:mousedown={handleStart}
        on:mousemove={handleMove}
        on:mouseup={handleEnd}
        on:mouseleave={handleEnd}
        on:touchstart={handleStart}
        on:touchmove={handleMove}
        on:touchend={handleEnd}
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
        class="bg-red-500 hover:bg-red-600 text-white font-medium px-8 py-3 rounded-lg transition-colors duration-200"
      >
        Don't Know
      </button>
      
      <button
        on:click={handleKnown}
        class="bg-green-500 hover:bg-green-600 text-white font-medium px-8 py-3 rounded-lg transition-colors duration-200"
      >
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
    user-select: none;
    -webkit-user-select: none;
    -moz-user-select: none;
    -ms-user-select: none;
    touch-action: pan-x;
  }
  
  .flashcard-face {
    position: absolute;
    width: 100%;
    height: 100%;
    backface-visibility: hidden;
    border: 2px solid transparent;
    transition: border-color 0.2s;
    pointer-events: none;
  }
  
  .flashcard-container:hover .flashcard-face {
    border-color: #3b82f6;
  }
  
  .flashcard-back {
    transform: rotateY(180deg);
  }
  
  /* Allow pointer events on card content but prevent dragging */
  .flashcard-face > * {
    pointer-events: auto;
  }
</style>