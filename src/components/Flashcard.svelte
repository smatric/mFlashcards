<script>
  import { createEventDispatcher, onMount } from 'svelte';

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
  let frontTextElement;
  let backTextElement;

  function toggleCard() {
    showDefinition = !showDefinition;
  }

  function handleKnown() {
    dispatch('known');
  }

  function handleUnknown() {
    dispatch('unknown');
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

      // Wait 100ms then fade in the new card
      setTimeout(() => {
        shouldTransition = true;
        cardOpacity = 1;
        isAnimating = false;
        hasMoved = false;
      }, 100);
    }, 200);
  }

  // React to card changes and reset showDefinition for new card
  $: if (currentCard && !isAnimating) {
    showDefinition = false;
  }

  // Determine what to show based on study mode
  $: showWordFirst = studyMode === 'word-to-definition';

  // Dynamic font sizing based on text length
  function getDynamicFontSize(text) {
    if (!text) return '2rem';

    const length = text.length;

    // Base sizes for different length ranges
    if (length <= 20) return '2.25rem';
    if (length <= 40) return '2rem';
    if (length <= 80) return '1.75rem';
    if (length <= 100) return '1.5rem';
    if (length <= 120) return '1.25rem';
    return '1rem';
  }

  // Get font sizes for current content
  $: frontText = showWordFirst ? currentCard?.word || '' : currentCard?.definition || '';
  $: backText = showWordFirst ? currentCard?.definition || '' : currentCard?.word || '';
  $: frontFontSize = getDynamicFontSize(frontText);
  $: backFontSize = getDynamicFontSize(backText);

  // Text-to-Speech functionality
  function playSound(text) {
    if ('speechSynthesis' in window) {
      // Cancel any ongoing speech
      window.speechSynthesis.cancel();

      // Android fix: Small delay to ensure cancellation completes
      setTimeout(() => {
        const utterance = new SpeechSynthesisUtterance(text);
        utterance.rate = 0.8; // Slightly slower for learning
        utterance.volume = 0.7;
        utterance.lang = 'en-US'; // Explicitly set language for Android

        // Android fix: Handle voice selection more robustly
        const setVoiceAndSpeak = () => {
          const voices = window.speechSynthesis.getVoices();
          if (voices.length > 0) {
            const englishVoice = voices.find(voice =>
              voice.lang.startsWith('en') || voice.lang.includes('en')
            );
            if (englishVoice) {
              utterance.voice = englishVoice;
            }
          }

          // Android fix: Additional error handling
          try {
            window.speechSynthesis.speak(utterance);
          } catch (error) {
            console.error('Speech synthesis error:', error);
            // Fallback: try again without voice selection
            const fallbackUtterance = new SpeechSynthesisUtterance(text);
            fallbackUtterance.rate = 0.8;
            fallbackUtterance.volume = 0.7;
            fallbackUtterance.lang = 'en-US';
            window.speechSynthesis.speak(fallbackUtterance);
          }
        };

        // Android fix: Wait for voices to load if needed
        const voices = window.speechSynthesis.getVoices();
        if (voices.length === 0) {
          // Voices not loaded yet, wait for them
          window.speechSynthesis.addEventListener('voiceschanged', setVoiceAndSpeak, { once: true });
          // Fallback timeout in case voiceschanged doesn't fire
          setTimeout(setVoiceAndSpeak, 100);
        } else {
          setVoiceAndSpeak();
        }
      }, 50);
    }
  }

  // Calculate background tint based on swipe distance and direction
  $: swipeIntensity = Math.min(Math.abs(translateX) / 150, 0.3); // Max 30% opacity
  $: swipeDirection = translateX > 0 ? 'right' : 'left';
  $: backgroundTint = isDragging && Math.abs(translateX) > 20 ?
    (swipeDirection === 'right' ? `rgba(34, 197, 94, ${swipeIntensity})` : `rgba(239, 68, 68, ${swipeIntensity})`) :
    'transparent';

  // Global keyboard event handling
  onMount(() => {
    const handleGlobalKeydown = (event) => {
      // Only handle if no input elements are focused
      if (document.activeElement?.tagName === 'INPUT' || document.activeElement?.tagName === 'TEXTAREA') {
        return;
      }

      if (event.key === 'ArrowLeft') {
        event.preventDefault();
        handleUnknown(); // Hard
      } else if (event.key === 'ArrowRight') {
        event.preventDefault();
        handleKnown(); // Easy
      }
    };

    window.addEventListener('keydown', handleGlobalKeydown);

    return () => {
      window.removeEventListener('keydown', handleGlobalKeydown);
    };
  });
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
        <div class="flashcard-face flashcard-front bg-white dark:bg-gray-800 shadow-xl rounded-xl p-8 h-[300px] flex flex-col relative">
          <!-- Background tint overlay -->
          <div 
            class="absolute inset-0 rounded-xl transition-all duration-75 ease-out"
            style="background-color: {backgroundTint}; pointer-events: none;"
          ></div>
          
          <div class="flex flex-col h-full justify-center text-center relative z-10">
            <div class="text-sm text-gray-500 dark:text-gray-400 mb-2 flex-shrink-0">
              {showWordFirst ? 'Word' : 'Definition'}
            </div>
            <div class="flex items-center justify-center gap-3 mb-6 flex-1 min-h-0">
              <div 
                bind:this={frontTextElement}
                class="card-content-text text-gray-800 dark:text-white font-semibold"
                style="font-size: {frontFontSize};"
              >
                {showWordFirst ? currentCard.word : currentCard.definition}
              </div>
              <!-- Show sound icon when currently displaying a word -->
              {#if 'speechSynthesis' in window && ((showWordFirst ? currentCard.word : currentCard.definition) === currentCard.word)}
                <button
                  on:click={(e) => {
                    e.preventDefault();
                    e.stopPropagation();
                    e.stopImmediatePropagation();
                    playSound(currentCard.word);
                  }}
                  class="flex-shrink-0 p-2 rounded-full bg-blue-100 hover:bg-blue-200 dark:bg-blue-800 dark:hover:bg-blue-700 transition-colors duration-200 text-blue-600 dark:text-blue-300 relative z-50"
                  title="Play pronunciation"
                >
                  <svg class="w-4 h-4" fill="currentColor" viewBox="0 0 24 24">
                    <path d="M3 9v6h4l5 5V4L7 9H3zm13.5 3c0-1.77-1.02-3.29-2.5-4.03v8.05c1.48-.73 2.5-2.25 2.5-4.02zM14 3.23v2.06c2.89.86 5 3.54 5 6.71s-2.11 5.85-5 6.71v2.06c4.01-.91 7-4.49 7-8.77s-2.99-7.86-7-8.77z"/>
                  </svg>
                </button>
              {/if}
            </div>
            <div class="text-sm text-gray-500 dark:text-gray-400 flex-shrink-0">
              Click to reveal {showWordFirst ? 'definition' : 'word'}
            </div>
          </div>
        </div>
        
        <!-- Back of card -->
        <div class="flashcard-face flashcard-back bg-blue-50 dark:bg-blue-900 shadow-xl rounded-xl p-8 h-[300px] flex flex-col relative">
          <!-- Background tint overlay -->
          <div 
            class="absolute inset-0 rounded-xl transition-all duration-75 ease-out"
            style="background-color: {backgroundTint}; pointer-events: none;"
          ></div>
          
          <div class="flex flex-col h-full justify-center text-center relative z-20">
            <div class="text-sm text-gray-600 dark:text-gray-300 mb-2 flex-shrink-0">
              {showWordFirst ? 'Definition' : 'Word'}
            </div>
            <div class="flex items-center justify-center gap-3 flex-1 min-h-0">
              <div 
                bind:this={backTextElement}
                class="card-content-text text-blue-800 dark:text-blue-200 font-semibold"
                style="font-size: {backFontSize};"
              >
                {showWordFirst ? currentCard.definition : currentCard.word}
              </div>
              <!-- Show sound icon when currently displaying a word -->
              {#if 'speechSynthesis' in window && ((showWordFirst ? currentCard.definition : currentCard.word) === currentCard.word)}
                <button
                  on:click={(e) => {
                    e.preventDefault();
                    e.stopPropagation();
                    e.stopImmediatePropagation();
                    playSound(currentCard.word);
                  }}
                  class="flex-shrink-0 p-2 rounded-full bg-blue-200 hover:bg-blue-300 dark:bg-blue-700 dark:hover:bg-blue-600 transition-colors duration-200 text-blue-700 dark:text-blue-200 relative z-50"
                  title="Play pronunciation"
                >
                  <svg class="w-4 h-4" fill="currentColor" viewBox="0 0 24 24">
                    <path d="M3 9v6h4l5 5V4L7 9H3zm13.5 3c0-1.77-1.02-3.29-2.5-4.03v8.05c1.48-.73 2.5-2.25 2.5-4.02zM14 3.23v2.06c2.89.86 5 3.54 5 6.71s-2.11 5.85-5 6.71v2.06c4.01-.91 7-4.49 7-8.77s-2.99-7.86-7-8.77z"/>
                  </svg>
                </button>
              {/if}
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
        Hard
      </button>
      
      <button
        on:click={handleKnown}
        class="bg-green-500 hover:bg-green-600 text-white font-medium px-8 py-3 rounded-lg transition-colors duration-200"
      >
        Easy
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
  }
  
  .flashcard-container:hover .flashcard-face {
    border-color: #3b82f6;
  }
  
  .flashcard-back {
    transform: rotateY(180deg);
  }
  
  /* Z-index management for proper layering when flipped */
  .flashcard-front {
    z-index: 2;
  }
  
  .flashcard-back {
    z-index: 1;
  }
  
  /* When card is flipped, back face should be on top */
  .rotate-y-180 .flashcard-front {
    z-index: 1;
  }
  
  .rotate-y-180 .flashcard-back {
    z-index: 2;
  }
  
  /* Allow pointer events on card content */
  .flashcard-face > * {
    pointer-events: auto;
  }

  /* Dynamic text content sizing */
  .card-content-text {
    /* Dynamic font size set via inline style */
    line-height: 1.3;
    
    /* Enable text wrapping */
    word-wrap: break-word;
    overflow-wrap: break-word;
    hyphens: auto;
    
    /* Constrain to available space - no scrolling */
    max-width: 100%;
    max-height: 100%;
    overflow: hidden;
    
    /* Center align content */
    display: flex;
    align-items: center;
    justify-content: center;
    text-align: center;
    
    /* Smooth transitions for font size changes */

    /* Ensure text fits within container */
    padding: 0.5rem;
    box-sizing: border-box;
  }

  /* Mobile responsive adjustments - smaller base sizes */
  @media (max-width: 768px) {
    .card-content-text {
      line-height: 1.2;
      padding: 0.25rem;
    }
  }
</style>