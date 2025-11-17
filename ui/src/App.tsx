import React, { useState, useEffect } from 'react';
import DeathScreen from './components/DeathScreen';
import MedicalPanel from './components/MedicalPanel';
import InspectionPanel from './components/InspectionPanel';

interface AppState {
  currentView: 'hidden' | 'death-screen' | 'medical-panel' | 'inspection-panel';
  deathScreenData: {
    message: string;
    seconds: number;
    canRespawn?: boolean;
    medicsOnDuty?: number;
    translations?: { [key: string]: string };
  };
  medicalData: {
    wounds: any;
    treatments: any[];
    infections?: any;
    bodyPartHealth?: any;
    injuryStates?: any;
    infectionStages?: any;
    bodyParts?: any;
    uiColors?: any;
    inventory?: any;
    bandageTypes?: any;
    isSelfExamination?: boolean;
    translations?: { [key: string]: string };
  };
  inspectionData: {
    playerName: string;
    vitals: any;
    injuries: any[];
    treatments: any[];
    inventory: any;
    translations?: { [key: string]: string };
    [key: string]: any; // Allow any additional properties from Lua
  };
}

function App() {
  const [state, setState] = useState<AppState>({
    currentView: 'hidden',
    deathScreenData: { message: '', seconds: 0, canRespawn: false, medicsOnDuty: 0, translations: {} },
    medicalData: { wounds: {}, treatments: [], infections: {}, bodyPartHealth: {}, injuryStates: {}, infectionStages: {}, bodyParts: {}, uiColors: {}, inventory: {}, bandageTypes: {}, isSelfExamination: false, translations: {} },
    inspectionData: { playerName: '', vitals: {}, injuries: [], treatments: [], inventory: {}, translations: {} }
  });

  useEffect(() => {
    const handleMessage = (event: MessageEvent) => {
      const { type, data } = event.data;
      
      switch (type) {
        case 'show-death-screen':
          setState(prev => ({
            ...prev,
            currentView: 'death-screen',
            deathScreenData: data
          }));
          break;
          
        case 'update-death-timer':
          setState(prev => ({
            ...prev,
            deathScreenData: { ...prev.deathScreenData, ...data }
          }));
          break;
          
        case 'hide-death-screen':
          setState(prev => ({
            ...prev,
            currentView: 'hidden'
          }));
          break;
          
        case 'show-medical-panel':
          setState(prev => ({
            ...prev,
            currentView: 'medical-panel',
            medicalData: data
          }));
          break;
          
        case 'show-inspection-panel':
          setState(prev => ({
            ...prev,
            currentView: 'inspection-panel',
            inspectionData: data
          }));
          break;
          
        case 'update-medical-data':
          console.log('Received update-medical-data:', data);
          console.log('Treatments in update:', data.treatments);
          setState(prev => ({
            ...prev,
            medicalData: {
              ...prev.medicalData,
              ...data
            }
          }));
          break;
          
        case 'hide-all':
          setState(prev => ({
            ...prev,
            currentView: 'hidden'
          }));
          break;
      }
    };

    window.addEventListener('message', handleMessage);
    
    // Make body visible in development
    if (process.env.NODE_ENV === 'development') {
      document.body.style.display = 'block';
    }

    return () => window.removeEventListener('message', handleMessage);
  }, []);

  const hideAll = () => {
    setState(prev => ({ ...prev, currentView: 'hidden' }));
    
    // Send message to client to disable NUI focus
    try {
      fetch(`https://${(window as any).GetParentResourceName()}/close-medical-panel`, {
        method: 'POST',
        headers: { 'Content-Type': 'application/json' },
        body: JSON.stringify({})
      }).catch(() => {});
    } catch (error) {
      // Fallback for development
      console.log('Would close medical panel');
    }
  };


  return (
    <div className="App" style={{ width: '100vw', height: '100vh', position: 'fixed', top: 0, left: 0 }}>
      {/* Debug info */}
      {process.env.NODE_ENV === 'development' && (
        <div style={{ position: 'fixed', top: 0, left: 0, background: 'rgba(0,0,0,0.8)', color: 'white', padding: '5px', zIndex: 9999, fontSize: '12px' }}>
          Current View: {state.currentView}
        </div>
      )}
      
      {state.currentView === 'death-screen' && (
        <DeathScreen
          message={state.deathScreenData.message}
          seconds={state.deathScreenData.seconds}
          canRespawn={state.deathScreenData.canRespawn}
          medicsOnDuty={state.deathScreenData.medicsOnDuty}
          translations={state.deathScreenData.translations}
        />
      )}
      
      {state.currentView === 'medical-panel' && (
        <MedicalPanel
          wounds={state.medicalData.wounds}
          treatments={state.medicalData.treatments}
          infections={state.medicalData.infections}
          bodyPartHealth={state.medicalData.bodyPartHealth}
          injuryStates={state.medicalData.injuryStates}
          infectionStages={state.medicalData.infectionStages}
          bodyParts={state.medicalData.bodyParts}
          uiColors={state.medicalData.uiColors}
          inventory={state.medicalData.inventory}
          bandageTypes={state.medicalData.bandageTypes}
          isSelfExamination={state.medicalData.isSelfExamination}
          translations={state.medicalData.translations}
          onClose={hideAll}
        />
      )}
      
      {state.currentView === 'inspection-panel' && (
        <InspectionPanel
          data={state.inspectionData}
          translations={state.inspectionData.translations}
          onClose={hideAll}
        />
      )}
    </div>
  );
}

export default App;