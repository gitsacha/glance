(async () => {
  window.glanceReady = false;
  if (typeof renderMathInElement === 'function') {
    renderMathInElement(document.querySelector('main'), {
      delimiters: [{left:'$$',right:'$$',display:true},{left:'\\[',right:'\\]',display:true},
        {left:'\\(',right:'\\)',display:false},{left:'$',right:'$',display:false}],
      throwOnError:false, trust:false, maxExpand:1000, maxSize:50
    });
  }
  if (typeof mermaid !== 'undefined') {
    const appearance = matchMedia('(prefers-color-scheme: dark)');
    const diagrams = Array.from(document.querySelectorAll('code.language-mermaid')).slice(0,20)
      .filter(code => code.textContent.length <= 50000)
      .map(code => ({node:code.parentElement, source:code.textContent}));
    // Serialize redraws so rapid appearance changes cannot race Mermaid's shared renderer.
    let queue = Promise.resolve();
    const redraw = () => {
      queue = queue.then(async () => {
        window.glanceReady = false;
        mermaid.initialize({startOnLoad:false, securityLevel:'strict',
          secure:['secure','securityLevel','startOnLoad','maxTextSize','maxEdges'],
          theme:appearance.matches ? 'dark' : 'default', maxTextSize:50000, maxEdges:500,
          flowchart:{htmlLabels:false}});
        for (const {node, source} of diagrams) {
          node.className = 'mermaid'; node.textContent = source;
          node.removeAttribute('data-processed');
          try { await mermaid.run({nodes:[node], suppressErrors:true}); }
          catch (_) { node.textContent = source; }
        }
        window.glanceReady = true;
        document.dispatchEvent(new Event('glance-ready'));
      });
      return queue;
    };
    appearance.addEventListener('change', () => { redraw(); });
    await redraw();
  } else {
    window.glanceReady = true;
    document.dispatchEvent(new Event('glance-ready'));
  }
})();
