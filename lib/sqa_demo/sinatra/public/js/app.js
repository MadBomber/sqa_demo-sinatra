// Global functions for modal and navigation

// Track the target route for navigation
let navTargetRoute = 'dashboard';

function showTickerModal(targetRoute = 'dashboard') {
  navTargetRoute = targetRoute;
  document.getElementById('tickerModal').style.display = 'block';
  document.getElementById('tickerInput').focus();
}

function closeTickerModal() {
  document.getElementById('tickerModal').style.display = 'none';
}

function navigateToStock(route) {
  showTickerModal(route);
}

function showCompareModal() {
  navTargetRoute = 'compare';
  document.getElementById('tickerModal').style.display = 'block';
  const input = document.getElementById('tickerInput');
  input.placeholder = 'Enter 2-5 tickers separated by spaces (e.g., AAPL MSFT GOOGL)';
  input.focus();
}

function searchTicker(event) {
  event.preventDefault();

  const input = event.target.querySelector('input[type="text"]');
  const inputValue = input.value.trim().toUpperCase();

  if (!inputValue) {
    alert('Please enter a stock ticker symbol');
    return false;
  }

  // Split by whitespace to check for multiple tickers
  const tickers = inputValue.split(/\s+/).filter(t => t.length > 0);

  // Validate each ticker format (letters and optional dot)
  const tickerPattern = /^[A-Z]{1,5}(\.[A-Z]{1,2})?$/;
  const invalidTickers = tickers.filter(t => !tickerPattern.test(t));

  if (invalidTickers.length > 0) {
    alert(`Invalid ticker symbol(s): ${invalidTickers.join(', ')}\nPlease use valid symbols (e.g., AAPL, BRK.A)`);
    return false;
  }

  // Check maximum of 5 tickers for comparison
  if (tickers.length > 5) {
    alert('Maximum of 5 tickers allowed for comparison. Please reduce your selection.');
    return false;
  }

  // If multiple tickers, go to comparison page
  if (tickers.length > 1) {
    window.location.href = `/compare?tickers=${tickers.join('+')}`;
    return false;
  }

  // Single ticker - navigate to the target route (dashboard, analyze, or backtest)
  window.location.href = `/${navTargetRoute}/${tickers[0]}`;
  return false;
}

// Change period from header selector
function changePeriod(period) {
  // Get current URL path
  const path = window.location.pathname;

  // Construct new URL with period parameter
  const url = new URL(window.location.href);
  url.searchParams.set('period', period);

  // Reload page with new period
  window.location.href = url.toString();
}

// Close modal when clicking outside
window.onclick = function(event) {
  const modal = document.getElementById('tickerModal');
  if (event.target === modal) {
    closeTickerModal();
  }
}

// Keyboard shortcuts
document.addEventListener('keydown', function(event) {
  // Ctrl/Cmd + K to open search
  if ((event.ctrlKey || event.metaKey) && event.key === 'k') {
    event.preventDefault();
    showTickerModal();
  }

  // Escape to close modal
  if (event.key === 'Escape') {
    closeTickerModal();
  }
});

// Utility functions
function formatCurrency(value) {
  return new Intl.NumberFormat('en-US', {
    style: 'currency',
    currency: 'USD'
  }).format(value);
}

function formatPercent(value) {
  return `${value >= 0 ? '+' : ''}${value.toFixed(2)}%`;
}

function formatNumber(value) {
  return new Intl.NumberFormat('en-US').format(value);
}

// Show loading indicator
function showLoading(elementId) {
  const element = document.getElementById(elementId);
  if (element) {
    element.innerHTML = '<p class="loading"><i class="fas fa-spinner fa-spin"></i> Loading...</p>';
  }
}

// Show error message
function showError(elementId, message) {
  const element = document.getElementById(elementId);
  if (element) {
    element.innerHTML = `<p class="error"><i class="fas fa-exclamation-circle"></i> ${message}</p>`;
  }
}

// Debounce function for performance
function debounce(func, wait) {
  let timeout;
  return function executedFunction(...args) {
    const later = () => {
      clearTimeout(timeout);
      func(...args);
    };
    clearTimeout(timeout);
    timeout = setTimeout(later, wait);
  };
}

// Console welcome message
console.log('%cSQA Analytics', 'font-size: 24px; font-weight: bold; color: #2196F3;');
console.log('%cPowered by Ruby & ApexCharts.js', 'font-size: 14px; color: #666;');
console.log('');
console.log('Keyboard shortcuts:');
console.log('  Ctrl/Cmd + K: Open ticker search');
console.log('  Escape: Close modal');
