(() => {
  const SUPABASE_URL = 'https://yxnzhhlribtiqhtqfoky.supabase.co';
  const SUPABASE_PUBLISHABLE_KEY = 'sb_publishable_luvPjOV0_pNflVGNMrOMKw_XqWrq_ob';
  const ADMIN_EMAILS = ['rosaifuddin749@gmail.com', 'c2022adams@gmail.com'].map(email => email.toLowerCase());
  const TABLES = [
    ['nightwatch_cases','Cases'],
    ['nightwatch_warrants','Warrants'],
    ['nightwatch_suspects','Suspects'],
    ['nightwatch_detectives','Detectives'],
    ['nightwatch_activity','Activity']
  ];
  const $ = id => document.getElementById(id);
  const client = window.supabase.createClient(SUPABASE_URL, SUPABASE_PUBLISHABLE_KEY, {
    auth: { persistSession: true, autoRefreshToken: true, detectSessionInUrl: true }
  });
  const setMessage = (id, text, kind='') => { $(id).textContent = text; $(id).className = 'message ' + kind; };
  const showSignedOut = () => { $('loginView').classList.remove('hidden'); $('adminView').classList.add('hidden'); };
  const showSignedIn = (email) => { $('loginView').classList.add('hidden'); $('adminView').classList.remove('hidden'); $('signedInAs').textContent = 'Authenticated as ' + email; };
  async function loadData() {
    $('results').innerHTML = '<div class="muted">Loading table information…</div>';
    $('tableCards').innerHTML = '';
    const cards = [];
    const blocks = [];
    for (const [table,label] of TABLES) {
      const { data, error } = await client.from(table).select('*').limit(5);
      if (error) {
        cards.push('<div class="metric"><span>'+label+'</span><b>—</b><small>Access check failed</small></div>');
        blocks.push('<article class="table-result"><header><b>'+label+'</b><span>Unavailable</span></header><pre>'+escapeHtml(error.message)+'</pre></article>');
      } else {
        const count = data.length;
        const columns = count ? Object.keys(data[0]).join(', ') : 'No rows returned; columns not inferred.';
        cards.push('<div class="metric"><span>'+label+'</span><b>'+count+'</b><small>Up to 5 sample rows loaded</small></div>');
        blocks.push('<article class="table-result"><header><b>'+label+'</b><span>Read access OK</span></header><pre>Columns: '+escapeHtml(columns)+'\n\nSample rows:\n'+escapeHtml(JSON.stringify(data,null,2))+'</pre></article>');
      }
    }
    $('tableCards').innerHTML = cards.join('');
    $('results').innerHTML = blocks.join('');
    setMessage('systemMessage','Database read checks finished. No records were changed.','ok');
  }
  function escapeHtml(value) { return String(value).replace(/[&<>"]/g, c => ({'&':'&amp;','<':'&lt;','>':'&gt;','"':'&quot;'}[c])); }
  $('loginForm').addEventListener('submit', async event => {
    event.preventDefault();
    const email = $('email').value.trim().toLowerCase();
    const password = $('password').value;
    if (!ADMIN_EMAILS.includes(email)) { setMessage('loginMessage','This account is not on the approved administrator list.','error'); return; }
    setMessage('loginMessage','Signing in…');
    const { data, error } = await client.auth.signInWithPassword({ email, password });
    if (error) { setMessage('loginMessage',error.message,'error'); return; }
    if (!data.user || !ADMIN_EMAILS.includes(data.user.email?.toLowerCase())) {
      await client.auth.signOut();
      setMessage('loginMessage','This account is not authorized for the admin console.','error');
      return;
    }
    setMessage('loginMessage','Signed in. Loading database checks…','ok');
    showSignedIn(data.user.email);
    await loadData();
  });
  $('signOut').addEventListener('click', async () => { await client.auth.signOut(); showSignedOut(); setMessage('loginMessage','You have signed out.','ok'); });
  $('refresh').addEventListener('click', loadData);
  client.auth.onAuthStateChange((_event, session) => {
    if (!session) { showSignedOut(); return; }
    if (!ADMIN_EMAILS.includes(session.user.email?.toLowerCase())) { client.auth.signOut(); showSignedOut(); return; }
    showSignedIn(session.user.email);
    setTimeout(loadData,0);
  });
  client.auth.getSession().then(({data}) => {
    const user = data.session?.user;
    if (user && ADMIN_EMAILS.includes(user.email?.toLowerCase())) { showSignedIn(user.email); loadData(); }
    else if (user) { client.auth.signOut(); showSignedOut(); }
    else showSignedOut();
  });
})();