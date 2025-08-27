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
  let cardOpacity = 1;
  let shouldTransition = true;
  let hasMoved = false;
  
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
    hasMoved = false;
    startX = e.type === 'mousedown' ? e.clientX : e.touches[0].clientX;
    currentX = startX;
    translateX = 0;
  }

  function handleMove(e) {
    if (!isDragging || isAnimating) return;
    e.preventDefault();
    currentX = e.type === 'mousemove' ? e.clientX : e.touches[0].clientX;
    translateX = currentX - startX;
    
    // Mark as moved if moved more than a few pixels
    if (Math.abs(translateX) > 5) {
      hasMoved = true;
    }
    
    // Limit the drag distance
    translateX = Math.max(-200, Math.min(200, translateX));
  }

  function handleEnd(e) {
    if (!isDragging || isAnimating) return;
    isDragging = false;
    
    const threshold = 80;
    
    if (translateX > threshold) {
      // Swipe right - "I Know This"
      if (e) e.preventDefault(); // Prevent click event
      isAnimating = true;
      animateCardOut(() => handleKnown());
    } else if (translateX < -threshold) {
      // Swipe left - "Don't Know"
      if (e) e.preventDefault(); // Prevent click event
      isAnimating = true;
      animateCardOut(() => handleUnknown());
    } else if (hasMoved) {
      // Small movement but not a swipe - prevent click
      if (e) e.preventDefault();
      isAnimating = true;
      translateX = 0;
      setTimeout(() => {
        isAnimating = false;
      }, 200);
    } else {
      // No significant movement - allow click to proceed
      isAnimating = false;
    }
  }

  function animateCardOut(callback) {
    // Slide card out further in the swipe direction
    translateX = translateX > 0 ? 400 : -400;
    
    setTimeout(() => {
      // Trigger the action (which will change the card)
      callback();
      
      // Disable transitions and reset position immediately
      shouldTransition = false;
      cardOpacity = 0;
      translateX = 0;
      
      // Wait 200ms then fade in the new card
      setTimeout(() => {
        shouldTransition = true;
        cardOpacity = 1;
        isAnimating = false;
        hasMoved = false;
      }, 200);
    }, 200);
  }

  // React to card changes and reset showDefinition for new card
  $: if (currentCard && !isAnimating) {
    showDefinition = false;
  }

  // Determine what to show based on study mode
  $: showWordFirst = studyMode === 'word-to-definition';
  
  // Calculate background tint based on swipe distance and direction
  $: swipeIntensity = Math.min(Math.abs(translateX) / 150, 0.3); // Max 30% opacity
  $: swipeDirection = translateX > 0 ? 'right' : 'left';
  $: backgroundTint = isDragging && Math.abs(translateX) > 20 ? 
    (swipeDirection === 'right' ? `rgba(34, 197, 94, ${swipeIntensity})` : `rgba(239, 68, 68, ${swipeIntensity})`) : 
    'transparent';
</script>

{#if currentCard}
  <div class="max-w-2xl mx-auto">
    <!-- Flashcard -->
    <div class="relative perspective-1000 mb-8">
      
      <div 
        bind:this={cardElement}
        class="flashcard-container cursor-pointer transform-style-preserve-3d {shouldTransition ? 'transition-all duration-200' : ''} {showDefinition ? 'rotate-y-180' : ''}"
        style="transform: translateX({translateX}px) {showDefinition ? 'rotateY(180deg)' : ''}; opacity: {cardOpacity}"
        on:click={(e) => {
          // Only allow flip if we haven't moved during this interaction
          if (!isAnimating) {
            toggleCard();
          }
        }}
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
        <div class="flashcard-face flashcard-front bg-white dark:bg-gray-800 shadow-xl rounded-xl p-8 min-h-[300px] flex items-center justify-center relative">
          <!-- Background tint overlay -->
          <div 
            class="absolute inset-0 rounded-xl transition-all duration-75 ease-out"
            style="background-color: {backgroundTint}; pointer-events: none;"
          ></div>
          
          <div class="text-center relative z-10">
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
        <div class="flashcard-face flashcard-back bg-blue-50 dark:bg-blue-900 shadow-xl rounded-xl p-8 min-h-[300px] flex items-center justify-center relative">
          <!-- Background tint overlay -->
          <div 
            class="absolute inset-0 rounded-xl transition-all duration-75 ease-out"
            style="background-color: {backgroundTint}; pointer-events: none;"
          ></div>
          
          <div class="text-center relative z-10">
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
  
  .transition-opacity {
    transition: opacity 200ms ease-in-out;
  }
</style>