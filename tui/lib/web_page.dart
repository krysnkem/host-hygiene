// The ONE page the look chooser serves: static HTML, CSS and a few lines of JS. No external request, no font, no image file; sample data only (nothing is scanned).
// __CURRENT__ is replaced with a validated look id before sending; the token is read by the page from its own URL path.
const String choosePage = r'''<!doctype html>
<html lang="en"><head><meta charset="utf-8"><meta name="viewport" content="width=device-width,initial-scale=1">
<title>host-hygiene: choose a look</title>
<style>
:root{color-scheme:light dark;--bg:#f6f7fb;--panel:#fff;--term:#161826;--tfg:#d7dbef;--line:#c9cde0;--fg:#1c1e2e;--dim:#5a5f7d;--acc:#5b3fc4;--accfg:#fff;--g:#8bd5a0;--y:#f1d589;--r:#e76170;--c:#8bd5ca;--m:#c6a0f6;--d:#8087a8;--sel:#2a2e48;--ok:#1b7a3c}
@media (prefers-color-scheme:dark){:root{--bg:#0f1117;--panel:#161826;--term:#0b0d16;--line:#3a3f5c;--fg:#d7dbef;--dim:#9aa0c0;--acc:#c6a0f6;--accfg:#17142b;--ok:#8bd5a0}}
*{box-sizing:border-box}
body{margin:0;background:var(--bg);color:var(--fg);font:16px/1.5 -apple-system,"Segoe UI",Helvetica,Arial,sans-serif}
.wrap{max-width:1000px;margin:0 auto;padding:20px 16px 110px}
h1{font-size:24px;margin:0 0 4px}p{margin:4px 0}.dim{color:var(--dim)}
.hy{display:flex;gap:14px;align-items:center;margin:14px 0 6px}
.face{font:700 28px Menlo,Consolas,monospace;color:#b8860b;white-space:nowrap}
@media (prefers-color-scheme:dark){.face{color:var(--y)}}
.say{border:1px solid var(--line);background:var(--panel);border-radius:12px;padding:8px 14px}
.grid{display:grid;grid-template-columns:repeat(auto-fill,minmax(min(100%,440px),1fr));gap:16px;margin-top:16px}
label.card{display:block;position:relative;border:2px solid var(--line);background:var(--panel);border-radius:12px;padding:12px;cursor:pointer}
label.card:hover{border-color:var(--dim)}
label.card:has(input:checked){border-color:var(--acc);box-shadow:0 0 0 2px var(--acc)}
label.card:has(input:focus-visible){outline:3px solid var(--acc);outline-offset:2px}
.card input{position:absolute;opacity:0;pointer-events:none}
.card h2{font-size:18px;margin:0;display:flex;gap:8px;align-items:baseline;flex-wrap:wrap}
.tag{font:12px Menlo,Consolas,monospace;color:var(--dim)}
.cur{font-size:12px;border:1px solid var(--dim);border-radius:10px;padding:0 8px;color:var(--dim)}
.card p{margin:2px 0 8px}
pre.t{margin:0;background:var(--term);color:var(--tfg);border-radius:8px;padding:10px;overflow-x:auto;font:12px/1.35 Menlo,Consolas,"Liberation Mono",monospace;white-space:pre}
.g{color:var(--g)}.y{color:var(--y)}.r{color:var(--r)}.c{color:var(--c)}.m{color:var(--m)}.d{color:var(--d)}.s{background:var(--sel);display:inline-block;width:100%}
.min{margin-top:8px;font-size:13px;color:var(--dim)}
.bar{position:fixed;left:0;right:0;bottom:0;background:var(--panel);border-top:1px solid var(--line);padding:12px 16px}
.bar div{max-width:1000px;margin:0 auto;display:flex;gap:14px;align-items:center;flex-wrap:wrap}
button{font:600 16px inherit;font-family:inherit;background:var(--acc);color:var(--accfg);border:0;border-radius:8px;padding:10px 24px;cursor:pointer}
button:disabled{opacity:.45;cursor:not-allowed}
button:focus-visible{outline:3px solid var(--fg);outline-offset:2px}
#msg{font-weight:600}#msg.ok{color:var(--ok)}#msg.bad{color:#c0392b}
</style></head><body><div class="wrap">
<h1>Choose how host-hygiene looks</h1>
<p class="dim">Pick a design, then Save. You can change it any time with <code>hh look</code> or the L key.</p>
<div class="hy"><span class="face" aria-hidden="true">(&bull;&#7447;&bull;)</span><span class="say">Hi, I am Hy. Every look has me in it and none of them removes anything without your yes.</span></div>
<p class="dim">The previews below use sample data. Nothing on your machine was scanned. If your terminal is too small for a look, I show the plain list instead.</p>
<form id="f" class="grid" onsubmit="return false">

<label class="card"><input type="radio" name="look" value="guided"><h2>Guided journey <span class="tag">guided</span></h2>
<p>One question per screen, with Hy front and centre. The friendliest first impression.</p>
<pre class="t" aria-label="Guided journey preview"><span class="g">1 Look</span> <span class="g">===</span> <span class="m">2 Pick</span> <span class="d">--- 3 Confirm --- 4 Done</span>
+- Hy ---------------------------------+
| <span class="y">(&bull;&#7447;&bull;)</span> <span class="c">I found 5 things safe to clear.</span> |
|   <span class="g">4.2G my-app/build</span>                   |
|   <span class="g">2.7G web-shop/build</span>                  |
+---------------------------------------+
<span class="s m"> &gt; Take me through them</span>
<span class="d">enter choose | arrows move | esc back</span></pre>
<div class="min">Needs a terminal of at least 30 columns by 6 rows.</div></label>

<label class="card"><input type="radio" name="look" value="cockpit"><h2>Cockpit <span class="tag">cockpit</span></h2>
<p>Everything on one screen, like lazygit. The cost of the highlighted item is always visible.</p>
<pre class="t" aria-label="Cockpit preview">+- host-hygiene -----------------------+
| <span class="y">(&bull;&#7447;&bull;)</span> <span class="c">All good. 19 GiB free, load 7.2</span> |
+- Kinds ---+- Safe to clear --+- About -+
|<span class="s g">&gt;Safe     5</span>|<span class="s g">&gt;[x] 4.2G build</span> | <span class="c">build</span>   |
| <span class="y">Ask      7</span> | <span class="g"> [x] 2.7G build</span> | git:<span class="g">yes</span>|
| <span class="d">Manual   2</span> | <span class="g"> [ ] 1.4G build</span> | slower |
+-----------+------------------+  once   +
<span class="d">space tick | a all safe | enter review</span></pre>
<div class="min">Needs a terminal of at least 60 columns by 16 rows.</div></label>

<label class="card"><input type="radio" name="look" value="dashboard"><h2>Dashboard <span class="tag">dashboard</span></h2>
<p>Live and moving, like btop. Best at answering why the machine is slow.</p>
<pre class="t" aria-label="Dashboard preview">+- Disk ---------------+- Load (10 cores) ---+
| 19.1 GiB free of 460 | now <span class="y">7.2</span>  limit 8      |
| <span class="g">██████████████</span><span class="d">░░░░░░░░</span> | <span class="y">▁▂▃▃▅▇▆▄▃▃▄▅▃▂</span>       |
| <span class="c">▇▆▆▅▅▄▄▃▃▃▂▂</span>         | <span class="y">(&bull;_&bull;)</span>               |
+- Heaviest processes -+- Reclaimable -------+
| <span class="r">qemu-system  87%</span>     | <span class="g">safe      21.9G</span>      |
| <span class="r">Code        108%</span>     | <span class="y">ask-first 83.7G</span>      |
+----------------------+---------------------+
<span class="d">tab focus | c clean | g can I build?</span></pre>
<div class="min">Needs a terminal of at least 60 columns by 14 rows.</div></label>

<label class="card"><input type="radio" name="look" value="spacemap"><h2>Space map <span class="tag">spacemap</span></h2>
<p>Size is shape, like a treemap. The big blocks are where your space went.</p>
<pre class="t" aria-label="Space map preview">~ / everything   460 GiB, 19 GiB free
<span class="y">+- Gradle 19.1G -----+</span><span class="d">+- Emulators 15.4G -+</span>
<span class="y">| modules-2   4.6G   |</span><span class="d">| Pixel_5      5.8G |</span>
<span class="y">| 8.12        3.8G   |</span><span class="d">| Pixel_8      5.1G |</span>
<span class="y">+--------------------+</span><span class="d">+-------------------+</span>
<span class="g">+- build/ 8.3G ----+</span><span class="y">+- Caches 16.5G ---+</span>
<span class="g">| my-app     4.2G  |</span><span class="y">| Google     8.0G  |</span>
<span class="g">+------------------+</span><span class="y">+------------------+</span>
<span class="d">arrows move | enter open | b back</span></pre>
<div class="min">Needs a terminal of at least 40 columns by 10 rows.</div></label>

<label class="card"><input type="radio" name="look" value="console"><h2>Command console <span class="tag">console</span></h2>
<p>Compact and fast for people who like keys, like k9s. Hy lives in the status line.</p>
<pre class="t" aria-label="Console preview"><span class="m">host-hygiene</span> &gt; space &gt; <span class="c">gradle</span>      <span class="g">(&bull;&#7447;&bull;) all good</span>
<span class="d">NAME        SIZE   CLASS       AGE</span>
<span class="s y">modules-2   4.6G   ask-first   10d</span>
<span class="y">8.12        3.8G   ask-first   34d</span>
<span class="y">7.6.3       2.1G   ask-first  210d</span>
<span class="g">9.8.1       0.7G   unused      13d</span>
<span class="d">d describe | x clear | / filter | ? help</span>
<span class="m">:</span>clean safe<span class="c">_</span></pre>
<div class="min">Needs a terminal of at least 50 columns by 10 rows.</div></label>

</form></div>
<div class="bar"><div><button id="save" type="button" disabled>Save</button><span id="msg" role="status" aria-live="polite">Choose a design.</span></div></div>
<script>
(function(){
var T=location.pathname.split('/')[1],cur='__CURRENT__',f=document.getElementById('f'),b=document.getElementById('save'),m=document.getElementById('msg'),sel='',done=false;
var rs=f.querySelectorAll('input');
for(var i=0;i<rs.length;i++){(function(r){
 if(r.value===cur){r.checked=true;sel=cur;b.disabled=false;m.textContent='Current look: '+cur+'.';
  var c=document.createElement('span');c.className='cur';c.textContent='current';r.parentNode.querySelector('h2').appendChild(c);}
 r.addEventListener('change',function(){sel=r.value;if(!done){b.disabled=false;m.className='';m.textContent='Selected '+sel+'. Press Save.';}});
})(rs[i]);}
b.addEventListener('click',function(){
 if(!sel||done)return;b.disabled=true;m.className='';m.textContent='Saving...';
 fetch('/'+T+'/save',{method:'POST',headers:{'Content-Type':'application/json'},body:JSON.stringify({look:sel,token:T})}).then(function(r){
  if(r.ok){done=true;m.className='ok';m.textContent='Saved. You can close this tab.';for(var i=0;i<rs.length;i++)rs[i].disabled=true;}
  else{m.className='bad';m.textContent='Could not save (error '+r.status+'). Go back to the terminal.';b.disabled=false;}
 }).catch(function(){m.className='bad';m.textContent='The terminal stopped waiting. Go back to the terminal.';});
});
})();
</script></body></html>
''';
