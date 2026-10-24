// ============================================================
// Shared auth layer — included on every page via <script src="auth.js">
// Requires: supabase-js CDN + config.js loaded first.
// ============================================================

window.sb = window.supabase.createClient(window.SUPABASE_URL, window.SUPABASE_ANON_KEY);

const LizAuth = (() => {
  let currentProfile = null;

  async function loadProfile() {
    const { data: { session } } = await sb.auth.getSession();
    if (!session) { currentProfile = null; return null; }
    const { data } = await sb
      .from('profiles')
      .select('id, full_name, avatar_url, role')
      .eq('id', session.user.id)
      .single();
    currentProfile = data ? { ...data, email: session.user.email } : null;
    return currentProfile;
  }

  function isAdmin() {
    return !!currentProfile && currentProfile.role === 'admin';
  }

  function getProfile() { return currentProfile; }

  // ---------------- Modal ----------------
  function injectModal() {
    if (document.getElementById('authModal')) return;
    const wrap = document.createElement('div');
    wrap.id = 'authModal';
    wrap.className = 'auth-modal-overlay';
    wrap.innerHTML = `
      <div class="auth-modal">
        <button class="auth-modal-close" id="authModalClose">&times;</button>
        <div id="authTabSignIn">
          <h3>Log In</h3>
          <div class="field"><label>Email</label><input type="email" id="signInEmail"></div>
          <div class="field"><label>Password</label><input type="password" id="signInPassword"></div>
          <button class="btn btn-solid" id="signInBtn" style="width:100%; justify-content:center;">Log In</button>
          <p class="auth-switch">New here? <a href="#" id="showSignUp">Create an account</a></p>
        </div>
        <div id="authTabSignUp" style="display:none;">
          <h3>Create Account</h3>
          <div class="field"><label>Full name</label><input type="text" id="signUpName"></div>
          <div class="field"><label>Email</label><input type="email" id="signUpEmail"></div>
          <div class="field"><label>Password</label><input type="password" id="signUpPassword"></div>
          <button class="btn btn-solid" id="signUpBtn" style="width:100%; justify-content:center;">Create Account</button>
          <p class="auth-switch">Already have an account? <a href="#" id="showSignIn">Log in</a></p>
        </div>
        <p class="auth-error" id="authError"></p>
      </div>
    `;
    document.body.appendChild(wrap);

    document.getElementById('authModalClose').onclick = closeModal;
    wrap.addEventListener('click', (e) => { if (e.target === wrap) closeModal(); });
    document.getElementById('showSignUp').onclick = (e) => { e.preventDefault(); switchTab('up'); };
    document.getElementById('showSignIn').onclick = (e) => { e.preventDefault(); switchTab('in'); };

    document.getElementById('signInBtn').onclick = async () => {
      const email = document.getElementById('signInEmail').value.trim();
      const password = document.getElementById('signInPassword').value;
      setError('');
      const { error } = await sb.auth.signInWithPassword({ email, password });
      if (error) return setError(error.message);
      closeModal();
      await refreshUI();
      window.dispatchEvent(new CustomEvent('liz-auth-change'));
    };

    document.getElementById('signUpBtn').onclick = async () => {
      const full_name = document.getElementById('signUpName').value.trim();
      const email = document.getElementById('signUpEmail').value.trim();
      const password = document.getElementById('signUpPassword').value;
      setError('');
      const { error } = await sb.auth.signUp({ email, password, options: { data: { full_name } } });
      if (error) return setError(error.message);
      setError('Account created! Check your email to confirm, then log in.', true);
    };
  }

  function switchTab(tab) {
    document.getElementById('authTabSignIn').style.display = tab === 'in' ? 'block' : 'none';
    document.getElementById('authTabSignUp').style.display = tab === 'up' ? 'block' : 'none';
    setError('');
  }

  function setError(msg, ok) {
    const el = document.getElementById('authError');
    el.textContent = msg;
    el.style.color = ok ? 'var(--gold)' : '#ff8a80';
  }

  function openModal(tab = 'in') {
    injectModal();
    switchTab(tab);
    document.getElementById('authModal').classList.add('open');
  }

  function closeModal() {
    const m = document.getElementById('authModal');
    if (m) m.classList.remove('open');
  }

  // ---------------- Nav widget ----------------
  async function refreshUI() {
    await loadProfile();
    const slot = document.getElementById('authSlot');
    if (!slot) return;
    if (currentProfile) {
      slot.innerHTML = `
        <div class="nav-auth-user">
          <img src="${currentProfile.avatar_url || 'https://static.wixstatic.com/media/02ca65_7b9c92cf080f4b809edfbe81f3a5fe5e~mv2.jpg'}" alt="${currentProfile.full_name || 'Account'}">
          <span>${currentProfile.full_name || currentProfile.email}${currentProfile.role === 'admin' ? ' · Admin' : ''}</span>
          <button id="logoutBtn">Log Out</button>
        </div>`;
      document.getElementById('logoutBtn').onclick = async () => {
        await sb.auth.signOut();
        await refreshUI();
        window.dispatchEvent(new CustomEvent('liz-auth-change'));
      };
    } else {
      slot.innerHTML = `<button class="nav-login-btn" id="navLoginBtn">Log In</button>`;
      document.getElementById('navLoginBtn').onclick = () => openModal('in');
    }
  }

  document.addEventListener('DOMContentLoaded', () => { injectModal(); refreshUI(); });
  sb.auth.onAuthStateChange(() => { refreshUI(); });

  return { getProfile, isAdmin, openModal, refreshUI, loadProfile };
})();

window.LizAuth = LizAuth;
