/**
 * Mermaid zoom client module — adds click-to-fullscreen to every rendered Mermaid
 * diagram. Inspired by GitHub's Mermaid lightbox.
 *
 * - Browser-only (guarded by ExecutionEnvironment.canUseDOM).
 * - Uses MutationObserver because Mermaid SVGs are injected asynchronously.
 * - Modal closes on Escape, backdrop click, or close button.
 * - Re-runs after Docusaurus client-side route transitions.
 */

import ExecutionEnvironment from '@docusaurus/ExecutionEnvironment';

if (ExecutionEnvironment.canUseDOM) {
  const CONTAINER_SELECTOR = 'div.docusaurus-mermaid-container';
  const ENHANCED_ATTR = 'data-zoom-enhanced';
  const MODAL_ID = 'mermaid-zoom-modal';

  const ensureModal = (): HTMLDivElement => {
    let modal = document.getElementById(MODAL_ID) as HTMLDivElement | null;
    if (modal) return modal;

    modal = document.createElement('div');
    modal.id = MODAL_ID;
    modal.setAttribute('role', 'dialog');
    modal.setAttribute('aria-modal', 'true');
    modal.setAttribute('aria-label', 'Diagram zoom view');
    modal.hidden = true;
    modal.innerHTML = `
      <div class="mermaid-zoom-backdrop"></div>
      <div class="mermaid-zoom-stage">
        <button type="button" class="mermaid-zoom-close" aria-label="Close (Esc)">×</button>
        <div class="mermaid-zoom-content"></div>
      </div>
    `;
    document.body.appendChild(modal);

    const close = () => {
      modal!.hidden = true;
      document.body.style.overflow = '';
      const content = modal!.querySelector('.mermaid-zoom-content');
      if (content) content.innerHTML = '';
    };

    modal.querySelector('.mermaid-zoom-close')?.addEventListener('click', close);
    modal.querySelector('.mermaid-zoom-backdrop')?.addEventListener('click', close);

    document.addEventListener('keydown', (e) => {
      if (!modal!.hidden && e.key === 'Escape') close();
    });

    return modal;
  };

  const openZoom = (sourceSvg: SVGSVGElement) => {
    const modal = ensureModal();
    const content = modal.querySelector('.mermaid-zoom-content') as HTMLDivElement;

    const clone = sourceSvg.cloneNode(true) as SVGSVGElement;
    clone.removeAttribute('width');
    clone.removeAttribute('height');
    clone.style.width = '100%';
    clone.style.height = '100%';
    clone.style.maxWidth = 'none';
    clone.style.maxHeight = 'none';
    if (!clone.getAttribute('preserveAspectRatio')) {
      clone.setAttribute('preserveAspectRatio', 'xMidYMid meet');
    }

    content.innerHTML = '';
    content.appendChild(clone);
    modal.hidden = false;
    document.body.style.overflow = 'hidden';
  };

  const enhance = (container: HTMLDivElement) => {
    if (container.getAttribute(ENHANCED_ATTR) === 'true') return;
    const svg = container.querySelector('svg');
    if (!svg) return;

    container.setAttribute(ENHANCED_ATTR, 'true');
    container.setAttribute('role', 'button');
    container.setAttribute('tabindex', '0');
    container.setAttribute('aria-label', 'Click to zoom diagram');
    container.title = 'Click to zoom';

    // Visual hint button (pure CSS via class — see custom.css)
    const hint = document.createElement('span');
    hint.className = 'mermaid-zoom-hint';
    hint.setAttribute('aria-hidden', 'true');
    hint.innerHTML = '⤢';
    container.appendChild(hint);

    container.addEventListener('click', (e) => {
      // Avoid hijacking text selection or link clicks within the SVG
      const target = e.target as Element;
      if (target?.closest('a')) return;
      openZoom(svg as SVGSVGElement);
    });
    container.addEventListener('keydown', (e) => {
      if (e.key === 'Enter' || e.key === ' ') {
        e.preventDefault();
        openZoom(svg as SVGSVGElement);
      }
    });
  };

  const scan = () => {
    document
      .querySelectorAll<HTMLDivElement>(CONTAINER_SELECTOR)
      .forEach((c) => enhance(c));
  };

  // Initial scan + on DOM changes (Mermaid renders asynchronously and
  // Docusaurus swaps content on client-side navigation).
  const observer = new MutationObserver(() => scan());
  observer.observe(document.body, { childList: true, subtree: true });

  // Run an initial scan when DOM is ready.
  if (document.readyState === 'loading') {
    document.addEventListener('DOMContentLoaded', scan);
  } else {
    scan();
  }
}
