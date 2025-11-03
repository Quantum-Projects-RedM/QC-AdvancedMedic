import React from 'react';
import ReactDOM from 'react-dom/client';
import './assets/css/deathscrn.css';
import './assets/css/medpanel.css';
import './assets/css/inspection.css';
import './assets/css/rightside-inspection.css';
import App from './App';

// Global CSS for NUI compatibility
document.documentElement.style.cssText = `
  width: 100vw !important;
  height: 100vh !important;
  margin: 0 !important;
  padding: 0 !important;
  overflow: hidden !important;
`;

document.body.style.cssText = `
  width: 100vw !important;
  height: 100vh !important;
  margin: 0 !important;
  padding: 0 !important;
  overflow: hidden !important;
  display: block !important;
  visibility: visible !important;
  opacity: 1 !important;
`;

const root = ReactDOM.createRoot(
  document.getElementById('root') as HTMLElement
);

root.render(
  <React.StrictMode>
    <App />
  </React.StrictMode>
);

// Initialize NUI listeners and development helpers
declare global {
  interface Window {
    medical: any;
  }
}

// Development mode helpers
if (process.env.NODE_ENV === 'development') {
  
  window.medical = {
    showDeathScreen: (data: any) => {
      window.postMessage({ type: 'show-death-screen', data }, '*');
    },
    showMedicalPanel: (data: any) => {
      window.postMessage({ type: 'show-medical-panel', data }, '*');
    },
    showInspectionPanel: (data: any) => {
      window.postMessage({ type: 'show-inspection-panel', data }, '*');
    },
    hideAll: () => {
      window.postMessage({ type: 'hide-all' }, '*');
    }
  };
  
}