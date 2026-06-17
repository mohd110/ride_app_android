// ═══════════════════════════════════════════════════════════
//                     RIDER CONNECT APP.JS
// ═══════════════════════════════════════════════════════════

// ─── State ───────────────────────────────────────────────
const state = {
    currentView: 'view-login',
    isOnline: false,
    hasActiveOrder: false,
    timerInterval: null,
    timerValue: 30,
    checkedItems: 0,
    totalCheckItems: 4,
};

// ─── DOM refs ─────────────────────────────────────────────
const $ = (id) => document.getElementById(id);

// ─── Clock ────────────────────────────────────────────────
function updateClock() {
    const now = new Date();
    const h = now.getHours().toString().padStart(2, '0');
    const m = now.getMinutes().toString().padStart(2, '0');
    const el = $('status-time');
    if (el) el.textContent = `${h}:${m}`;
}
updateClock();
setInterval(updateClock, 30000);

// ─── View Navigation ──────────────────────────────────────
function navigate(viewId) {
    document.querySelectorAll('.view').forEach(v => v.classList.remove('active'));
    const target = $(viewId);
    if (target) target.classList.add('active');
    state.currentView = viewId;

    const tabViews = ['view-offline', 'view-online', 'view-earnings', 'view-profile'];
    const bottomTabs = $('bottom-tabs');
    if (bottomTabs) {
        bottomTabs.style.display = tabViews.includes(viewId) ? 'flex' : 'none';
    }

    // Sync tab highlights
    if (viewId === 'view-offline' || viewId === 'view-online') {
        setTabActive('tab-tasks');
    } else if (viewId === 'view-earnings') {
        setTabActive('tab-earnings');
    } else if (viewId === 'view-profile') {
        setTabActive('tab-profile');
    }

    // Update status bar text color based on view
    updateStatusBarColor(viewId);

    // Draw chart when earnings tab opens
    if (viewId === 'view-earnings') {
        drawEarningsChart('daily');
    }
}

function setTabActive(tabId) {
    document.querySelectorAll('.tab-btn').forEach(b => b.classList.remove('active'));
    const btn = $(tabId);
    if (btn) btn.classList.add('active');
}

function updateStatusBarColor(viewId) {
    const statusBar = $('status-bar');
    if (!statusBar) return;
    const lightViews = ['view-offline', 'view-pickup', 'view-deliver', 'view-earnings', 'view-profile'];
    if (lightViews.includes(viewId)) {
        statusBar.style.color = '#1A1A2E';
    } else if (viewId === 'view-login') {
        statusBar.style.color = '#1A1A2E';
    } else {
        statusBar.style.color = '#1A1A2E';
    }
}

// ─── Tab Switcher ─────────────────────────────────────────
function switchTab(tab) {
    switch (tab) {
        case 'tasks':
            navigate(state.isOnline ? 'view-online' : 'view-offline');
            break;
        case 'earnings':
            navigate('view-earnings');
            break;
        case 'profile':
            navigate('view-profile');
            break;
    }
}

// ─── Alert Popup ──────────────────────────────────────────
function showAlert(msg, duration = 3000) {
    const popup = $('alert-popup');
    const text = $('alert-text');
    if (!popup || !text) return;
    text.textContent = msg;
    popup.classList.add('active');
    setTimeout(() => popup.classList.remove('active'), duration);
}

// ─── LOGIN ────────────────────────────────────────────────
$('btn-login').addEventListener('click', () => {
    const user = $('login-user').value.trim();
    const pass = $('login-pass').value.trim();
    const errEl = $('login-error');

    if (!user || !pass) {
        errEl.textContent = 'Please enter username and password.';
        return;
    }
    if (user.toLowerCase() !== 'admin' || pass !== 'admin') {
        errEl.textContent = '❌ Invalid credentials. Try admin / admin';
        $('login-pass').value = '';
        return;
    }

    errEl.textContent = '';
    navigate('view-offline');
    $('bottom-tabs').style.display = 'flex';
    setTimeout(() => showAlert('Welcome back, Alex! 👋', 3000), 400);
});

// Allow Enter key on password
$('login-pass').addEventListener('keydown', (e) => {
    if (e.key === 'Enter') $('btn-login').click();
});
$('login-user').addEventListener('keydown', (e) => {
    if (e.key === 'Enter') $('login-pass').focus();
});

// ─── GO ONLINE ────────────────────────────────────────────
$('btn-go-online').addEventListener('click', () => {
    state.isOnline = true;
    navigate('view-online');
    setTimeout(() => {
        showAlert('You are now ONLINE. Searching for orders...', 3000);
        // Trigger assignment after 4s
        setTimeout(triggerNewAssignment, 4000);
    }, 500);
});

// ─── GO OFFLINE ───────────────────────────────────────────
$('btn-go-offline').addEventListener('click', () => {
    state.isOnline = false;
    cancelAssignment();
    navigate('view-offline');
    showAlert('You went offline.', 2500);
});

// ─── NEW ASSIGNMENT ───────────────────────────────────────
function triggerNewAssignment() {
    if (state.currentView !== 'view-online') return;
    const overlay = $('assignment-overlay');
    if (!overlay) return;
    overlay.classList.add('active');
    state.timerValue = 30;
    updateTimerUI(30);
    state.timerInterval = setInterval(tickTimer, 1000);
    showAlert('🔔 New assignment received!', 2500);
}

function cancelAssignment() {
    const overlay = $('assignment-overlay');
    if (overlay) overlay.classList.remove('active');
    if (state.timerInterval) {
        clearInterval(state.timerInterval);
        state.timerInterval = null;
    }
}

function tickTimer() {
    state.timerValue--;
    updateTimerUI(state.timerValue);
    if (state.timerValue <= 0) {
        cancelAssignment();
        showAlert('⏰ Order expired. Searching for next order...', 3000);
        setTimeout(triggerNewAssignment, 5000);
    }
}

function updateTimerUI(val) {
    const txt = $('timer-text');
    const circle = $('timer-circle');
    if (!txt || !circle) return;

    txt.textContent = val;
    const circumference = 2 * Math.PI * 40;
    const progress = val / 30;
    circle.style.strokeDashoffset = circumference * (1 - progress);
    circle.style.stroke = val > 10 ? '#E53935' : '#F59E0B';
}

// Accept order
$('btn-accept').addEventListener('click', () => {
    cancelAssignment();
    state.hasActiveOrder = true;
    navigate('view-navigation');
    showAlert('✅ Order accepted! Navigating to pickup...', 3000);
});

// Decline order
$('btn-reject').addEventListener('click', () => {
    cancelAssignment();
    showAlert('Order declined. Searching again...', 2500);
    setTimeout(triggerNewAssignment, 5000);
});

// ─── ARRIVED AT DESTINATION ──────────────────────────────
$('btn-arrived').addEventListener('click', () => {
    navigate('view-pickup');
    showAlert('📍 Arrived at restaurant! Confirm your pickup items.', 3000);
});

// ─── ITEM CHECKLIST ───────────────────────────────────────
function toggleCheck(el) {
    el.classList.toggle('checked');
    // count checked items
    const allItems = document.querySelectorAll('#pickup-checklist .checklist-item');
    const checkedCount = document.querySelectorAll('#pickup-checklist .checklist-item.checked').length;
    state.checkedItems = checkedCount;
}

// Mark as Picked Up
$('btn-mark-picked').addEventListener('click', () => {
    const allItems = document.querySelectorAll('#pickup-checklist .checklist-item');
    const checkedCount = document.querySelectorAll('#pickup-checklist .checklist-item.checked').length;
    if (checkedCount < allItems.length) {
        showAlert(`⚠️ Please confirm all ${allItems.length} items before pickup.`, 3000);
        return;
    }
    navigate('view-deliver');
    showAlert('🚀 Items confirmed! Navigate to customer.', 3000);
});

// ─── SLIDE TO COMPLETE ───────────────────────────────────
const slideHandle = $('slide-handle');
const slideContainer = $('slide-container');
const slideBgFill = $('slide-bg-fill');
let isDragging = false;
let startX = 0;
let currentX = 0;
let maxSlide = 0;

function initSlide() {
    if (!slideContainer || !slideHandle) return;
    maxSlide = slideContainer.offsetWidth - slideHandle.offsetWidth - 8;
}

function onSlideStart(e) {
    isDragging = true;
    startX = (e.touches ? e.touches[0].clientX : e.clientX);
    slideHandle.style.transition = 'none';
    slideBgFill.style.transition = 'none';
    initSlide();
}

function onSlideMove(e) {
    if (!isDragging) return;
    const clientX = e.touches ? e.touches[0].clientX : e.clientX;
    currentX = Math.max(0, Math.min(clientX - startX, maxSlide));
    slideHandle.style.left = `${currentX + 4}px`;
    slideBgFill.style.width = `${(currentX / maxSlide) * 100}%`;
}

function onSlideEnd() {
    if (!isDragging) return;
    isDragging = false;
    slideHandle.style.transition = 'left 0.3s ease';
    slideBgFill.style.transition = 'width 0.3s ease';
    if (currentX >= maxSlide * 0.85) {
        slideHandle.style.left = `${maxSlide + 4}px`;
        slideBgFill.style.width = '100%';
        setTimeout(completeDelivery, 300);
    } else {
        slideHandle.style.left = '4px';
        slideBgFill.style.width = '0%';
        currentX = 0;
    }
}

if (slideHandle) {
    slideHandle.addEventListener('mousedown', onSlideStart);
    slideHandle.addEventListener('touchstart', onSlideStart, { passive: true });
    document.addEventListener('mousemove', onSlideMove);
    document.addEventListener('touchmove', onSlideMove, { passive: true });
    document.addEventListener('mouseup', onSlideEnd);
    document.addEventListener('touchend', onSlideEnd);
}

function completeDelivery() {
    const successOverlay = $('success-overlay');
    if (successOverlay) successOverlay.classList.add('active');
    state.hasActiveOrder = false;
    // Reset slide
    setTimeout(() => {
        if (slideHandle) slideHandle.style.left = '4px';
        if (slideBgFill) slideBgFill.style.width = '0%';
        currentX = 0;
    }, 500);
}

// ─── PHOTO UPLOAD (simulated) ────────────────────────────
function handlePhotoUpload() {
    const btn = $('photo-upload-btn');
    if (!btn) return;
    btn.innerHTML = `
        <svg viewBox="0 0 24 24" style="width:28px;height:28px;fill:var(--accent-green);margin-bottom:8px;"><path d="M9 16.17L4.83 12l-1.42 1.41L9 19 21 7l-1.41-1.41z"/></svg>
        <span style="color:var(--accent-green);">Photo captured ✓</span>
    `;
    btn.style.borderColor = 'var(--accent-green)';
    btn.style.background = '#E8F5E9';
}

// ─── EARNINGS CHART ──────────────────────────────────────
const chartData = {
    daily: [12.5, 18, 8.5, 22, 14.5, 19, 28],
    weekly: [142, 168, 155, 180, 198, 212, 225],
    monthly: [580, 620, 710, 780, 850, 920, 1248],
};
const chartLabels = {
    daily: ['Mon', 'Tue', 'Wed', 'Thu', 'Fri', 'Sat', 'Sun'],
    weekly: ['W1', 'W2', 'W3', 'W4', 'W5', 'W6', 'W7'],
    monthly: ['Jan', 'Feb', 'Mar', 'Apr', 'May', 'Jun', 'Jul'],
};

function drawEarningsChart(period) {
    const chart = $('earnings-chart');
    if (!chart) return;
    const data = chartData[period];
    const labels = chartLabels[period];
    const max = Math.max(...data);

    chart.innerHTML = data.map((val, i) => {
        const pct = (val / max * 100).toFixed(1);
        const isLast = i === data.length - 1;
        return `
            <div style="display:flex;flex-direction:column;align-items:center;gap:4px;flex:1;">
                <div style="font-size:10px;font-weight:700;color:${isLast ? 'var(--primary)' : 'var(--text-muted)'};">${period === 'daily' ? '$' + val : ''}</div>
                <div style="flex:1;display:flex;align-items:flex-end;width:100%;">
                    <div style="
                        width:100%;
                        height:${pct}%;
                        background:${isLast ? 'var(--primary)' : 'rgba(229,57,53,0.15)'};
                        border-radius:6px 6px 3px 3px;
                        min-height:4px;
                        transition:height 0.6s cubic-bezier(0.34,1.56,0.64,1);
                        ${isLast ? 'box-shadow:0 2px 8px rgba(229,57,53,0.3);' : ''}
                    "></div>
                </div>
                <div style="font-size:10px;color:var(--text-muted);font-weight:600;">${labels[i]}</div>
            </div>
        `;
    }).join('');
}

function selectPill(el, period) {
    document.querySelectorAll('.pill-option').forEach(p => p.classList.remove('active'));
    el.classList.add('active');
    drawEarningsChart(period);
}

// ─── LOGOUT ──────────────────────────────────────────────
$('btn-logout').addEventListener('click', () => {
    state.isOnline = false;
    state.hasActiveOrder = false;
    cancelAssignment();
    $('bottom-tabs').style.display = 'none';
    $('login-user').value = '';
    $('login-pass').value = '';
    navigate('view-login');
    showAlert('Signed out successfully.', 2500);
});

// ─── Init ─────────────────────────────────────────────────
window.addEventListener('load', () => {
    navigate('view-login');
    initSlide();
    // Pre-fill credentials for quick demo
    $('login-user').value = 'admin';
    $('login-pass').value = 'admin';
});

window.addEventListener('resize', initSlide);
