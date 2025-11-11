import React, { useState, useEffect, useRef } from 'react';

interface InspectionPanelProps {
  data: {
    playerName: string;
    playerId?: string; // Changed from number to string to match backend
    playerSource?: number; // Added for backend compatibility
    vitals?: {
      heartRate?: number;
      temperature?: number;
      breathing?: number;
      bloodPressure?: string;
      status?: string;
    };
    wounds?: {
      [bodyPart: string]: any; // Made flexible to accept any wound data from backend
    };
    treatments?: any; // Made flexible to accept backend treatment structure
    infections?: any; // Added for backend infection data
    bandages?: any; // Added for backend bandage data
    injuryStates?: any; // Added for backend config data
    infectionStages?: any; // Added for backend config data
    bodyParts?: any; // Added for backend config data
    uiColors?: any; // Added for backend config data
    inspectedBy?: string; // Added for backend data
    inspectionTime?: number; // Added for backend data
    injuries?: any[]; // Keep for compatibility
    inventory?: any; // Keep for compatibility
    bloodLevel?: number; // Keep for compatibility
    locale?: string; // Added for locale support
    translations?: {
      [key: string]: string; // Flat structure from Config.Strings
    };
  };
  onClose: () => void;
}

const InspectionPanel: React.FC<InspectionPanelProps> = ({ data, onClose }) => {
  // Listen for ESC key to close panel
  useEffect(() => {
    const handleKeyDown = (event: KeyboardEvent) => {
      if (event.key === 'Escape') {
        // Send close message to backend
        try {
          fetch(`https://${(window as any).GetParentResourceName()}/closeInspectionPanel`, {
            method: 'POST',
            headers: { 'Content-Type': 'application/json' },
            body: JSON.stringify({})
          }).catch(() => {});
        } catch (error) {}
        onClose();
      }
    };

    window.addEventListener('keydown', handleKeyDown);
    return () => window.removeEventListener('keydown', handleKeyDown);
  }, [onClose]);


  // Listen for backend responses
  useEffect(() => {
    const handleMessage = (event: MessageEvent) => {
      if (event.data.type === 'medical-treatment-response') {
        const { success, message, action, bodyPart, itemName, updatedConditions } = event.data;
        
        if (success) {
          showNotification(`${data.translations?.ui_successfullyApplied|| 'Successfully applied'} ${itemName} ${data.translations?.ui_to|| 'to'} ${bodyPart}`, 'fa-check-circle');
          
          // Add treatment to assessment log
          const bodyPartName = bodyPart !== 'patient' ? getBodyPartName(bodyPart) : 'patient';
          addTreatmentEntry(`${data.translations?.ui_applied|| 'Applied'} ${itemName} ${data.translations?.ui_to|| 'to'} ${bodyPartName}`);
          
          // Update patient conditions if provided by backend
          if (updatedConditions) {
            // This would trigger a re-render with new condition data
            // Backend should send updated wound/health data
            // Note: In production, you'd update the parent component's data state
            // For now, this shows the structure for condition updates
          }
          
          // Clear selections on success
          if (action === 'apply-bandage') {
            setSelectedBandageType(null);
            setSelectedBodyPart(null);
          } else if (action === 'apply-tourniquet') {
            setSelectedTourniquetType(null);
            setSelectedBodyPart(null);
          } else if (action === 'administer-medicine') {
            setSelectedMedicineType(null);
          } else if (action === 'give-injection') {
            setSelectedInjectionType(null);
          }
        } else {
          // Show inventory error with same notification style as other actions
          showNotification(message || `${data.translations?.ui_youDontHave || "You don't have"} ${itemName} ${data.translations?.ui_inYourInventory || 'in your inventory'}`, 'fa-times-circle');
        }
      } else if (event.data.type === 'patient-condition-update') {
        // Handle real-time condition updates from backend
        const { playerId, conditions } = event.data;
        if (playerId === data.playerId) {
          // This would update the displayed conditions in real-time
          // Backend sends new wound/bleeding data when conditions change
        }
      } else if (event.data.type === 'medical-config-data') {
        // Receive config data from backend
        const { bandageTypes, tourniquetTypes, medicineTypes, injectionTypes, bodyParts } = event.data;
        setConfigData({
          bandageTypes: bandageTypes || {},
          tourniquetTypes: tourniquetTypes || {},
          medicineTypes: medicineTypes || {},
          injectionTypes: injectionTypes || {},
          bodyParts: bodyParts || {}
        });
      } else if (event.data.type === 'vitals-response') {
        // Handle health response from backend for realistic pulse calculation
        const { health, isDead, isUnconscious } = event.data;
        console.log('[QC-AdvancedMedic] Received vitals-response:', { health, isDead, isUnconscious });
        updateVitalsFromHealth(health, isDead, isUnconscious);
      } else if (event.data.type === 'update-mission-wounds') {
        // Handle wound updates after mission treatments
        console.log('[QC-AdvancedMedic] Received wound update for mission NPC:', event.data.data);
        
        // Update the data by replacing it with the new wound data
        // This is a direct mutation which will trigger re-renders
        if (Number(data.playerId) === -1 && event.data.data) {
          const updatedData = event.data.data;
          
          // Update wound data directly
          Object.assign(data, {
            wounds: updatedData.wounds,
            treatments: updatedData.treatments,
            infections: updatedData.infections,
            bandages: updatedData.bandages,
            healthData: updatedData.healthData,
            bloodLevel: updatedData.bloodLevel,
            isBleeding: updatedData.isBleeding
          });
          
          // Force a re-render by updating a state variable
          setNotification({
            message: 'Patient condition updated after treatment',
            icon: 'fa-sync'
          });
          
          // Clear the notification after showing it
          setTimeout(() => setNotification(null), 2000);
          
          console.log('[MISSION UPDATE] Wound data refreshed after treatment');
        }
      } else if (event.data.type === 'tool-usage-result') {
        // Handle doctor bag tool usage results from server
        const { success, message } = event.data.data;

        if (success) {
          // Show success notification
          showNotification(message || 'Tool used successfully', 'fa-check-circle');
        } else {
          // Show error notification (e.g., missing item)
          showNotification(message || 'Unable to use tool', 'fa-times-circle');
        }
      }
    };

    window.addEventListener('message', handleMessage);
    
    // Automatically request initial vitals when panel opens
    setTimeout(() => {
      try {
        fetch(`https://${(window as any).GetParentResourceName()}/medical-request`, {
          method: 'POST',
          headers: { 'Content-Type': 'application/json' },
          body: JSON.stringify({
            action: 'check-vitals',
            data: {
              playerId: data.playerId,
              playerSource: data.playerSource
            }
          })
        }).catch(() => {});
      } catch (error) {
        // Fallback for web testing
        console.log('Auto vitals check - using fallback for web testing');
      }
    }, 500); // Small delay to ensure panel is ready
    
    return () => window.removeEventListener('message', handleMessage);
  }, []);

  // Test mode - simulate backend responses for web testing (only in development)
  const simulateBackendResponse = (action: string, itemName: string, displayName: string, bodyPart?: string) => {
    // Only simulate if not in RedM (for web testing)
    const isRedM = (window as any).GetParentResourceName !== undefined;
    if (isRedM) return; // Don't simulate in actual RedM environment
    
    // Simulate random success/failure for testing
    const hasItem = Math.random() > 0.3; // 70% success rate for testing
    
    setTimeout(() => {
      const responseData: any = {
        type: 'medical-treatment-response',
        success: hasItem,
        message: hasItem ? null : `You don't have ${displayName} in your inventory`,
        action: action,
        bodyPart: bodyPart || 'patient',
        itemName: displayName
      };

      // If successful, simulate condition improvements
      if (hasItem && bodyPart && bodyPart !== 'patient') {
        responseData.updatedConditions = {
          [bodyPart]: {
            bleeding: action === 'apply-bandage' ? Math.max(0, (Math.random() * 10)) : undefined, // Reduced bleeding
            health: action === 'apply-tourniquet' ? Math.min(100, 60 + (Math.random() * 20)) : undefined // Improved health
          }
        };
      }

      window.postMessage(responseData, '*');
    }, 1500); // Simulate backend delay
  };

  const [currentView, setCurrentView] = useState<'home' | 'bandage' | 'tourniquet' | 'medicine' | 'injection' | 'body-inspection' | 'vitals' | 'doctors-bag'>('home');
  const [ui_vitalsChecked, setVitalsChecked] = useState(false);
  const [selectedBone, setSelectedBone] = useState<string | null>(null);
  const [inspectedBones, setInspectedBones] = useState<Set<string>>(new Set());
  const [checkingVitals, setCheckingVitals] = useState(false);
  const [vitalsProgress, setVitalsProgress] = useState(0);
  const [detailedInspectionResults, setDetailedInspectionResults] = useState<{[bodyPart: string]: any}>({});
  const [selectedBandageType, setSelectedBandageType] = useState<string | null>(null);
  const [selectedTourniquetType, setSelectedTourniquetType] = useState<string | null>(null);
  const [selectedMedicineType, setSelectedMedicineType] = useState<string | null>(null);
  const [selectedInjectionType, setSelectedInjectionType] = useState<string | null>(null);
  const [selectedBodyPart, setSelectedBodyPart] = useState<string | null>(null);
  const [showVitalsSubMenu, setShowVitalsSubMenu] = useState(false);
  const [showDoctorsBagSubMenu, setShowDoctorsBagSubMenu] = useState(false);
  const [showThermometerSubMenu, setShowThermometerSubMenu] = useState(false);
  const [vitalsAnimating, setVitalsAnimating] = useState(false);
  const [ui_doctorsBagAnimating, setDoctorsBagAnimating] = useState(false);
  const [thermometerAnimating, setThermometerAnimating] = useState(false);
  const [checkingTemperature, setCheckingTemperature] = useState(false);
  const [temperatureProgress, setTemperatureProgress] = useState(0);
  const [temperatureChecked, setTemperatureChecked] = useState(false);
  const [hasInspectedFully, setHasInspectedFully] = useState(false);
  
  // State for real-time vitals data from backend
  const [currentPatientVitals, setCurrentPatientVitals] = useState<{
    heartRate: number;
    status: string;
    description: string;
    health: number;
  } | null>(null);
  
  // Ref for auto-scrolling
  const contentContainerRef = useRef<HTMLDivElement>(null);
  
  // Auto-scroll function
  const scrollToBottom = () => {
    if (contentContainerRef.current) {
      contentContainerRef.current.scrollTo({
        top: contentContainerRef.current.scrollHeight,
        behavior: 'smooth'
      });
    }
  };

  // Update vitals based on real health data from backend
  const updateVitalsFromHealth = (health: number, isDead: boolean, isUnconscious: boolean) => {
    console.log('[QC-AdvancedMedic] updateVitalsFromHealth called with:', { health, isDead, isUnconscious });
    let heartRate = 0;
    let status = '';
    let description = '';

    if (isDead) {
      heartRate = 0;
      status = data.translations?.vitals_noPulseDetected || 'No Pulse Detected';
      description = data.translations?.vitals_noPulse || 'Patient shows no signs of life. No pulse or breathing detected.';
    } else if (isUnconscious) {
      // Unconscious patients have weak pulse
      heartRate = 40 + Math.random() * 20; // 40-60 BPM
      status = data.translations?.vitals_weakPulseStatus || 'Weak Pulse';
      description = data.translations?.vitals_unconsciousPulse || 'Patient is unconscious. Weak, irregular pulse detected.';
    } else {
      // Calculate pulse based on health percentage
      const healthPercent = Math.max(0, Math.min(100, health));
      
      if (healthPercent >= 90) {
        heartRate = 60 + Math.random() * 20; // 60-80 BPM (normal)
        status = data.translations?.vitals_normalStatus || 'Normal';
        description = data.translations?.vitals_normalPulse || 'Strong, regular pulse. Patient appears stable.';
      } else if (healthPercent >= 75) {
        heartRate = 80 + Math.random() * 20; // 80-100 BPM (elevated)
        status = data.translations?.vitals_elevatedStatus || 'Elevated';
        description = data.translations?.vitals_elevatedPulse || 'Pulse slightly elevated. Patient may be in mild distress.';
      } else if (healthPercent >= 50) {
        heartRate = 100 + Math.random() * 30; // 100-130 BPM (fast)
        status = data.translations?.vitals_tachycardia || 'Tachycardia';
        description = data.translations?.vitals_fastPulse || 'Rapid pulse detected. Patient shows signs of significant distress.';
      } else if (healthPercent >= 25) {
        heartRate = 120 + Math.random() * 40; // 120-160 BPM (very fast)
        status = data.translations?.vitals_severeTachycardia || 'Severe Tachycardia';
        description = data.translations?.vitals_criticalPulse || 'Dangerously fast pulse. Patient in critical condition.';
      } else if (healthPercent > 0) {
        heartRate = 40 + Math.random() * 30; // 40-70 BPM (weak/irregular)
        status = data.translations?.vitals_weakIrregular || 'Weak & Irregular';
        description = data.translations?.vitals_weakPulse || 'Weak, irregular pulse. Patient is barely clinging to life.';
      }
    }

    // Round heart rate to whole number
    heartRate = Math.round(heartRate);

    // Update the vitals display
    // Force re-render by updating assessment
    if (ui_vitalsChecked) {
      addAssessmentEntry(`Updated vital signs: Heart rate ${heartRate} BPM - ${status}`);
      addAssessmentEntry(`Clinical assessment: ${description}`);
    }

    // Store the new vitals for display using React state
    setCurrentPatientVitals({
      heartRate,
      status,
      description,
      health: health
    });
  };
  
  const [notification, setNotification] = useState<{message: string, icon: string} | null>(null);
  const [discoveredInjuries, setDiscoveredInjuries] = useState<{[bodyPart: string]: any}>({});
  const [medicalAssessment, setMedicalAssessment] = useState<string[]>([]);
  const [treatmentsApplied, setTreatmentsApplied] = useState<string[]>([]);
  
  // Config data from backend - will be populated via events
  const [configData, setConfigData] = useState<any>({
    bandageTypes: {},
    tourniquetTypes: {},
    medicineTypes: {},
    injectionTypes: {},
    bodyParts: {}
  });

  // Auto-scroll when treatment is selected
  useEffect(() => {
    if (selectedBandageType && selectedBodyPart) {
      setTimeout(scrollToBottom, 100); // Small delay to let content render
    }
  }, [selectedBandageType, selectedBodyPart]);
  
  useEffect(() => {
    if (selectedTourniquetType && selectedBodyPart) {
      setTimeout(scrollToBottom, 100);
    }
  }, [selectedTourniquetType, selectedBodyPart]);
  
  useEffect(() => {
    if (selectedMedicineType) {
      setTimeout(scrollToBottom, 100);
    }
  }, [selectedMedicineType]);
  
  useEffect(() => {
    if (selectedInjectionType) {
      setTimeout(scrollToBottom, 100);
    }
  }, [selectedInjectionType]);

  // Calculate dynamic vitals based on wound data or real health data
  const calculateVitals = () => {
    // Check if we have real health data from backend
    if (currentPatientVitals) {
      // Determine statusColor based on heart rate and status
      let statusColor = '#27ae60'; // Default green
      
      if (currentPatientVitals.heartRate === 0 || currentPatientVitals.status.includes('No Pulse')) {
        statusColor = '#e74c3c'; // Red for dead/no pulse
      } else if (currentPatientVitals.heartRate < 50 || currentPatientVitals.status.includes('Weak')) {
        statusColor = '#f39c12'; // Orange for weak/critical
      } else if (currentPatientVitals.heartRate > 120 || currentPatientVitals.status.includes('Tachycardia')) {
        statusColor = '#e74c3c'; // Red for dangerous tachycardia
      } else if (currentPatientVitals.heartRate > 100 || currentPatientVitals.status.includes('Elevated')) {
        statusColor = '#f39c12'; // Orange for elevated
      }
      
      return {
        heartRate: currentPatientVitals.heartRate,
        status: currentPatientVitals.status,
        description: currentPatientVitals.description || currentPatientVitals.status,
        statusColor: statusColor
      };
    }

    // Fallback to wound-based calculation
    const bloodLevel = data.bloodLevel || 100;
    let baseHeartRate = 72;
    let totalSeverity = 0;

    // Calculate total severity from wounds (using painLevel and bleedingLevel)
    if (data.wounds) {
      Object.values(data.wounds).forEach(wound => {
        const severity = (wound.painLevel || 0) + (wound.bleedingLevel || 0) * 2; // Bleeding is more severe
        totalSeverity += severity;
      });
    }

    // Adjust heart rate based on blood loss and injuries
    if (bloodLevel < 50) baseHeartRate += 40;
    else if (bloodLevel < 70) baseHeartRate += 25;
    else if (bloodLevel < 90) baseHeartRate += 10;

    if (totalSeverity > 300) baseHeartRate += 20;
    else if (totalSeverity > 150) baseHeartRate += 10;

    const heartRate = Math.min(Math.max(baseHeartRate, 40), 180);

    // Determine patient status
    let status = data.translations?.ui_stable || 'Stable';
    let statusColor = '#27ae60';

    if (bloodLevel < 30 || totalSeverity > 400) {
      status = data.translations?.ui_critical || 'Critical';
      statusColor = '#e74c3c';
    } else if (bloodLevel < 60 || totalSeverity > 200) {
      status = data.translations?.ui_serious || 'Serious';
      statusColor = '#f39c12';
    } else if (bloodLevel < 80 || totalSeverity > 100) {
      status = data.translations?.ui_injured || 'Injured';
      statusColor = '#e67e22';
    }

    return { heartRate, status, statusColor };
  };

  const vitals = calculateVitals();

  // Convert config data to arrays for UI rendering - with fallbacks for testing
  const bandageTypes = Object.keys(configData.bandageTypes || {}).length > 0 
    ? Object.entries(configData.bandageTypes).map(([key, config]: [string, any]) => ({
        id: key,
        name: config.label || data.translations?.unknownBandage || 'Unknown Bandage',
        desc: config.description || '',
        icon: 'fa-band-aid',
        itemname: config.itemName || key,
        effectiveness: config.effectiveness || 50
      }))
    : [
        { id: 'cloth', name: 'Cloth Strip', desc: 'Basic cloth strip - crude but available', icon: 'fa-band-aid', itemname: 'cloth_band', effectiveness: 60 },
        { id: 'cotton', name: 'Cotton Bandage', desc: 'Standard cotton bandage - reliable frontier medicine', icon: 'fa-band-aid', itemname: 'cotton_band', effectiveness: 75 },
        { id: 'linen', name: 'Linen Wrap', desc: 'Quality linen wrap - superior absorbency', icon: 'fa-band-aid', itemname: 'linen_band', effectiveness: 85 },
        { id: 'sterile', name: 'Sterilized Gauze', desc: 'Professional medical gauze - sterile and effective', icon: 'fa-band-aid', itemname: 'sterile_band', effectiveness: 95 }
      ];

  const tourniquetTypes = Object.keys(configData.tourniquetTypes || {}).length > 0 
    ? Object.entries(configData.tourniquetTypes).map(([key, config]: [string, any]) => ({
        id: key,
        name: config.label || data.translations?.unknownTourniquet || 'Unknown Tourniquet',
        desc: `${data.translations?.effectiveness || 'Effectiveness'}: ${config.effectiveness || 70}% - ${data.translations?.maxDuration || 'Max duration'}: ${Math.floor((config.maxDuration || 1200) / 60)} min`,
        icon: 'fa-compress',
        itemname: config.itemName || key,
        effectiveness: config.effectiveness || 70
      }))
    : [
        { id: 'rope', name: 'Rope Tourniquet', desc: 'Improvised rope tourniquet - rough but effective', icon: 'fa-compress', itemname: 'tourniquet_rope', effectiveness: 70 },
        { id: 'leather', name: 'Leather Strap', desc: 'Leather strap tourniquet - durable frontier solution', icon: 'fa-compress', itemname: 'tourniquet_leather', effectiveness: 75 },
        { id: 'cloth', name: 'Cloth Tourniquet', desc: 'Cloth tourniquet - basic emergency bleeding control', icon: 'fa-compress', itemname: 'tourniquet_cloth', effectiveness: 65 },
        { id: 'medical', name: 'Medical Tourniquet', desc: 'Professional medical tourniquet - hospital grade', icon: 'fa-compress', itemname: 'tourniquet_medical', effectiveness: 95 }
      ];

  const medicineTypes = Object.keys(configData.medicineTypes || {}).length > 0 
    ? Object.entries(configData.medicineTypes).map(([key, config]: [string, any]) => ({
        id: key,
        name: config.label || data.translations?.unknownMedicine || 'Unknown Medicine',
        desc: config.description || '',
        icon: 'fa-prescription-bottle',
        itemname: config.itemName || key,
        effectiveness: config.effectiveness || 50
      }))
    : [
        { id: 'laudanum', name: 'Laudanum', desc: 'Opium-based painkiller - powerful but addictive', icon: 'fa-prescription-bottle', itemname: 'medicine_laudanum', effectiveness: 85 },
        { id: 'morphine', name: 'Morphine Powder', desc: 'Powerful opiate analgesic - strongest painkiller available', icon: 'fa-prescription-bottle', itemname: 'medicine_morphine', effectiveness: 95 },
        { id: 'whiskey', name: 'Medicinal Whiskey', desc: 'Alcohol-based antiseptic and anesthetic - frontier medicine', icon: 'fa-prescription-bottle', itemname: 'medicine_whiskey', effectiveness: 60 },
        { id: 'quinine', name: 'Quinine Powder', desc: 'Antimalarial and fever reducer - specialized treatment', icon: 'fa-prescription-bottle', itemname: 'medicine_quinine', effectiveness: 70 }
      ];

  const injectionTypes = Object.keys(configData.injectionTypes || {}).length > 0 
    ? Object.entries(configData.injectionTypes).map(([key, config]: [string, any]) => ({
        id: key,
        name: config.label || data.translations?.unknownInjection || 'Unknown Injection',
        desc: config.description || '',
        icon: 'fa-syringe',
        itemname: config.itemName || key,
        riskLevel: config.riskLevel || 'medium'
      }))
    : [
        { id: 'adrenaline', name: 'Adrenaline Shot', desc: 'Cardiac stimulant for emergency resuscitation - use with extreme caution', icon: 'fa-syringe', itemname: 'injection_adrenaline', riskLevel: 'high' },
        { id: 'cocaine', name: 'Cocaine Solution', desc: 'Local anesthetic for surgical procedures - numbs pain effectively', icon: 'fa-syringe', itemname: 'injection_cocaine', riskLevel: 'medium' },
        { id: 'strychnine', name: 'Strychnine (Micro)', desc: 'Stimulant for paralysis and respiratory failure - extremely dangerous', icon: 'fa-syringe', itemname: 'injection_strychnine', riskLevel: 'extreme' },
        { id: 'saline', name: 'Salt Water', desc: 'Hydration and blood volume replacement - safe basic treatment', icon: 'fa-syringe', itemname: 'injection_saline', riskLevel: 'low' }
      ];

  // Show notification
  const showNotification = (message: string, icon: string = 'fa-check-circle') => {
    setNotification({message, icon});
    setTimeout(() => setNotification(null), 4500);
  };

  // Animation helper functions
  const closeVitalsSubMenu = () => {
    setShowVitalsSubMenu(false);
    setVitalsAnimating(false);
  };

  const closeDoctorsBagSubMenu = () => {
    setShowDoctorsBagSubMenu(false);
    setDoctorsBagAnimating(false);
  };

  // Body part mapping between frontend and backend
  const mapFrontendToBackend = (frontendBodyPart: string): string => {
    const mapping: { [key: string]: string } = {
      'head': 'HEAD',
      'spine': 'SPINE', 
      'upbody': 'UPPER_BODY',
      'lowbody': 'LOWER_BODY',
      'larm': 'LARM',
      'rarm': 'RARM',
      'lhand': 'LHAND',
      'rhand': 'RHAND',
      'lleg': 'LLEG',
      'rleg': 'RLEG',
      'lfoot': 'LFOOT',
      'rfoot': 'RFOOT'
    };
    return mapping[frontendBodyPart.toLowerCase()] || frontendBodyPart.toUpperCase();
  };

  // Get body part display name from config or fallback
  const getBodyPartName = (bodyPart: string): string => {
    // Try config first with backend format
    const backendBodyPart = mapFrontendToBackend(bodyPart);
    if (configData.bodyParts && configData.bodyParts[backendBodyPart]) {
      return configData.bodyParts[backendBodyPart].label || configData.bodyParts[backendBodyPart];
    }
    
    // Fallback mapping for consistent display
    const fallbackNames: { [key: string]: string } = {
      'head': 'Head', 'spine': 'Spine', 'upbody': 'Upper Body', 'lowbody': 'Lower Body',
      'larm': 'Left Arm', 'rarm': 'Right Arm', 'lhand': 'Left Hand', 'rhand': 'Right Hand',
      'lleg': 'Left Leg', 'rleg': 'Right Leg', 'lfoot': 'Left Foot', 'rfoot': 'Right Foot'
    };
    
    return fallbackNames[bodyPart.toLowerCase()] || bodyPart;
  };

  // Get wound data for body part (with proper mapping)
  const getWoundData = (frontendBodyPart: string) => {
    if (!data.wounds) return null;
    const backendBodyPart = mapFrontendToBackend(frontendBodyPart);
    return data.wounds[backendBodyPart] || null;
  };

  // Check if body part needs medicine (any pain level) - check both discovered wounds and treatment status
  const needsMedicine = (frontendBodyPart: string): boolean => {
    // For treatment sections, use the discovered wound data directly since it's already validated
    const discoveredWound = discoveredInjuries[frontendBodyPart];
    if (!discoveredWound) return false;
    
    // Check if pain exists
    const hasPain = discoveredWound.painLevel && discoveredWound.painLevel > 0;
    if (!hasPain) return false;
    
    // For mission NPCs, check if pain has been treated by looking at the actual wound data
    if (Number(data.playerId) === -1 && data.wounds) {
      const backendBodyPart = mapFrontendToBackend(frontendBodyPart);
      const currentWound = data.wounds[backendBodyPart];
      
      // Check if there are any active pain treatments
      if (currentWound && currentWound.treatments) {
        for (const treatmentId in currentWound.treatments) {
          const treatment = currentWound.treatments[treatmentId];
          if (treatment.status === "active" && treatment.treatsCondition === "pain") {
            // Pain has been treated with medicine
            return false;
          }
        }
      }
    }
    
    // Pain needs treatment
    return true;
  };

  // Check if body part has bandageable bleeding (1-6) - always show discovered bleeding wounds
  const needsBandage = (frontendBodyPart: string): boolean => {
    // For treatment sections, use the discovered wound data directly since it's already validated
    const discoveredWound = discoveredInjuries[frontendBodyPart];
    if (!discoveredWound) return false;
    
    // Show all bleeding wounds in range 1-6, regardless of treatment status
    const hasBandageableBleeding = discoveredWound.bleedingLevel && discoveredWound.bleedingLevel >= 1 && discoveredWound.bleedingLevel <= 6;
    return hasBandageableBleeding;
  };

  // Check if a bandageable body part has been treated
  const isBandaged = (frontendBodyPart: string): boolean => {
    // For mission NPCs, check if bleeding has been treated
    if (Number(data.playerId) === -1 && data.wounds) {
      const backendBodyPart = mapFrontendToBackend(frontendBodyPart);
      const currentWound = data.wounds[backendBodyPart];
      
      // Check if there are any active bleeding treatments
      if (currentWound && currentWound.treatments) {
        for (const treatmentId in currentWound.treatments) {
          const treatment = currentWound.treatments[treatmentId];
          if (treatment.status === "active" && treatment.treatsCondition === "bleeding") {
            // Bleeding has been treated with bandage
            return true;
          }
        }
      }
    }
    
    return false;
  };

  // Check if body part has severe bleeding (7+) - always show discovered severe bleeding wounds
  const needsTourniquet = (frontendBodyPart: string): boolean => {
    // For treatment sections, use the discovered wound data directly since it's already validated
    const discoveredWound = discoveredInjuries[frontendBodyPart];
    if (!discoveredWound) return false;
    
    // Show all severe bleeding wounds (7+), regardless of treatment status
    const hasSevereBleeding = discoveredWound.bleedingLevel && discoveredWound.bleedingLevel >= 7;
    return hasSevereBleeding;
  };

  // Check if a severe bleeding body part has been treated with tourniquet
  const isTourniqueted = (frontendBodyPart: string): boolean => {
    // For mission NPCs, check if severe bleeding has been treated
    if (Number(data.playerId) === -1 && data.wounds) {
      const backendBodyPart = mapFrontendToBackend(frontendBodyPart);
      const currentWound = data.wounds[backendBodyPart];
      
      // Check if there are any active severe bleeding treatments
      if (currentWound && currentWound.treatments) {
        for (const treatmentId in currentWound.treatments) {
          const treatment = currentWound.treatments[treatmentId];
          if (treatment.status === "active" && treatment.treatsCondition === "severe_bleeding") {
            // Severe bleeding has been treated with tourniquet
            return true;
          }
        }
      }
    }
    
    return false;
  };

  // Add medical assessment entry
  const addAssessmentEntry = (entry: string) => {
    setMedicalAssessment(prev => {
      if (!prev.includes(entry)) {
        return [...prev, entry];
      }
      return prev;
    });
  };

  // Add treatment entry
  const addTreatmentEntry = (treatment: string) => {
    setTreatmentsApplied(prev => {
      const timestamp = new Date().toLocaleTimeString([], { hour: '2-digit', minute: '2-digit' });
      const entry = `${timestamp} - ${treatment}`;
      return [...prev, entry];
    });
  };

  // Reset animation states when submenus are shown
  useEffect(() => {
    if (showVitalsSubMenu && !vitalsAnimating) {
      setVitalsAnimating(true);
      setTimeout(() => setVitalsAnimating(false), 400);
    }
  }, [showVitalsSubMenu]);

  useEffect(() => {
    if (showDoctorsBagSubMenu && !ui_doctorsBagAnimating) {
      setDoctorsBagAnimating(true);
      setTimeout(() => setDoctorsBagAnimating(false), 400);
    }
  }, [showDoctorsBagSubMenu]);


  // Switch to different views
  const switchView = (view: typeof currentView) => {
    if (view === 'vitals') {
      // Close other submenus with animation
      if (showDoctorsBagSubMenu) {
        setDoctorsBagAnimating(true);
        setTimeout(() => {
          setShowDoctorsBagSubMenu(false);
          setDoctorsBagAnimating(false);
        }, 300);
      }
      if (showThermometerSubMenu) {
        setThermometerAnimating(true);
        setTimeout(() => {
          setShowThermometerSubMenu(false);
          setThermometerAnimating(false);
        }, 300);
      }
      // Show vitals with animation
      setShowVitalsSubMenu(true);
      setVitalsAnimating(true);
      return;
    }
    if (view === 'doctors-bag') {
      // Close other submenus with animation
      if (showVitalsSubMenu) {
        setVitalsAnimating(true);
        setTimeout(() => {
          setShowVitalsSubMenu(false);
          setVitalsAnimating(false);
        }, 300);
      }
      if (showThermometerSubMenu) {
        setThermometerAnimating(true);
        setTimeout(() => {
          setShowThermometerSubMenu(false);
          setThermometerAnimating(false);
        }, 300);
      }
      // Show doctor's bag with animation
      setShowDoctorsBagSubMenu(true);
      setDoctorsBagAnimating(true);
      return;
    }
    setCurrentView(view);
    setCheckingVitals(false);
    setVitalsProgress(0);
    setSelectedBandageType(null);
    setSelectedTourniquetType(null);
    setSelectedMedicineType(null);
    setSelectedInjectionType(null);
    setSelectedBodyPart(null);
    
    // Close all submenus with animation
    if (showVitalsSubMenu) {
      setVitalsAnimating(true);
      setTimeout(() => {
        setShowVitalsSubMenu(false);
        setVitalsAnimating(false);
      }, 300);
    }
    if (showDoctorsBagSubMenu) {
      setDoctorsBagAnimating(true);
      setTimeout(() => {
        setShowDoctorsBagSubMenu(false);
        setDoctorsBagAnimating(false);
      }, 300);
    }
    if (showThermometerSubMenu) {
      setThermometerAnimating(true);
      setTimeout(() => {
        setShowThermometerSubMenu(false);
        setThermometerAnimating(false);
      }, 300);
    }
  };

  // Interactive vitals checking (hold for 3 seconds)
  const startVitalsCheck = () => {
    if (checkingVitals) return;
    
    // First, request current health from backend for realistic pulse
    window.postMessage({
      type: 'medical-request',
      action: 'check-vitals',
      data: {
        playerId: data.playerId,
        playerSource: data.playerSource
      }
    }, '*');
    
    setCheckingVitals(true);
    setVitalsProgress(0);
    
    const interval = setInterval(() => {
      setVitalsProgress(prev => {
        if (prev >= 100) {
          clearInterval(interval);
          setVitalsChecked(true);
          setCheckingVitals(false);
          
          // Request real health data from backend
          try {
            fetch(`https://${(window as any).GetParentResourceName()}/medical-request`, {
              method: 'POST',
              headers: { 'Content-Type': 'application/json' },
              body: JSON.stringify({
                action: 'check-vitals',
                data: {
                  playerId: data.playerId,
                  playerSource: data.playerSource
                }
              })
            }).catch(() => {});
          } catch (error) {
            // Fallback to mock vitals if not in game
            console.log('Using mock vitals for web testing');
          }
          
          return 100;
        }
        return prev + 3.33; // 100% in 3 seconds
      });
    }, 100);
  };

  const stopVitalsCheck = () => {
    setCheckingVitals(false);
    setVitalsProgress(0);
  };

  // Temperature checking (hold for 3 seconds)
  const startTemperatureCheck = () => {
    if (checkingTemperature) return;
    setCheckingTemperature(true);
    setTemperatureProgress(0);
    
    const interval = setInterval(() => {
      setTemperatureProgress(prev => {
        if (prev >= 100) {
          clearInterval(interval);
          setTemperatureChecked(true);
          setCheckingTemperature(false);
          // Send completion to server
          window.postMessage({ 
            type: 'temperature-checked', 
            data: { 
              playerId: data.playerId,
              temperature: calculateTemperature()
            }
          }, '*');
          return 100;
        }
        return prev + 3.33; // 100% in 3 seconds
      });
    }, 100);
  };

  const stopTemperatureCheck = () => {
    setCheckingTemperature(false);
    setTemperatureProgress(0);
  };

  const calculateTemperature = () => {
    const baseTemp = 98.6;
    const bloodLevel = data.bloodLevel || 100;
    let totalSeverity = 0;

    if (data.wounds) {
      Object.values(data.wounds).forEach(wound => {
        const severity = (wound.painLevel || 0) + (wound.bleedingLevel || 0) * 2; // Bleeding is more severe
        totalSeverity += severity;
      });
    }

    // Fever from injuries/infection
    let tempAdjustment = 0;
    if (totalSeverity > 300) tempAdjustment += 3.5;
    else if (totalSeverity > 150) tempAdjustment += 2;
    else if (totalSeverity > 50) tempAdjustment += 1;

    // Hypothermia from blood loss
    if (bloodLevel < 30) tempAdjustment -= 2;
    else if (bloodLevel < 60) tempAdjustment -= 1;

    return Math.round((baseTemp + tempAdjustment) * 10) / 10;
  };


  // Apply bandage treatment
  const ui_applyBandage = () => {
    if (!selectedBandageType || !selectedBodyPart) return;
    
    const bandage = bandageTypes.find(b => b.id === selectedBandageType);
    
    showNotification(`${data.translations?.ui_checkingInventoryFor || 'Checking inventory for'} ${bandage?.name}...`, 'fa-clock');
    
    // Send to backend for inventory check and treatment using proper FiveM NUI method
    try {
      fetch(`https://${(window as any).GetParentResourceName()}/medical-treatment`, {
        method: 'POST',
        headers: { 'Content-Type': 'application/json' },
        body: JSON.stringify({
          action: 'apply-bandage',
          data: {
            playerId: data.playerId,
            bodyPart: selectedBodyPart,
            itemType: selectedBandageType,
            itemName: bandage?.itemname || bandage?.name || 'bandage',
            displayName: bandage?.name || 'Bandage'
          }
        })
      }).then(response => response.json()).then(result => {
        if (result.status === 'success') {
          showNotification(`Successfully applied ${bandage?.name} to ${selectedBodyPart}`, 'fa-check-circle');
          setSelectedBandageType(null);
          setSelectedBodyPart(null);
          
          // Add treatment to assessment log
          addTreatmentEntry(`Applied ${bandage?.name} to ${selectedBodyPart} for bleeding control`);
        } else {
          showNotification(result.message || `Failed to apply ${bandage?.name}`, 'fa-times-circle');
        }
      }).catch(error => {
        console.error('Bandage application failed:', error);
        showNotification('Bandage application failed', 'fa-times-circle');
      });
    } catch (error) {
      console.error('Failed to send bandage request:', error);
      // Fallback to simulate for web testing
      simulateBackendResponse('apply-bandage', bandage?.itemname || 'bandage', bandage?.name || 'Bandage', selectedBodyPart);
    }
  };

  // Apply tourniquet treatment
  const ui_applyTourniquet = () => {
    if (!selectedTourniquetType || !selectedBodyPart) return;
    
    const tourniquet = tourniquetTypes.find(t => t.id === selectedTourniquetType);
    
    showNotification(`${data.translations?.ui_checkingInventoryFor || 'Checking inventory for'} ${tourniquet?.name}...`, 'fa-clock');
    
    // Send to backend for inventory check and treatment using proper FiveM NUI method
    try {
      fetch(`https://${(window as any).GetParentResourceName()}/medical-treatment`, {
        method: 'POST',
        headers: { 'Content-Type': 'application/json' },
        body: JSON.stringify({
          action: 'apply-tourniquet',
          data: {
            playerId: data.playerId,
            bodyPart: selectedBodyPart,
            itemType: selectedTourniquetType,
            itemName: tourniquet?.itemname || tourniquet?.name || 'tourniquet',
            displayName: tourniquet?.name || 'Tourniquet'
          }
        })
      }).then(response => response.json()).then(result => {
        if (result.status === 'success') {
          showNotification(`Successfully applied ${tourniquet?.name} to ${selectedBodyPart}`, 'fa-check-circle');
          setSelectedTourniquetType(null);
          setSelectedBodyPart(null);
          
          // Add treatment to assessment log
          addTreatmentEntry(`Applied ${tourniquet?.name} to ${selectedBodyPart} for severe bleeding control`);
        } else {
          showNotification(result.message || `Failed to apply ${tourniquet?.name}`, 'fa-times-circle');
        }
      }).catch(error => {
        console.error('Tourniquet application failed:', error);
        showNotification('Tourniquet application failed', 'fa-times-circle');
      });
    } catch (error) {
      console.error('Failed to send tourniquet request:', error);
      // Fallback to simulate for web testing
      simulateBackendResponse('apply-tourniquet', tourniquet?.itemname || 'tourniquet', tourniquet?.name || 'Tourniquet', selectedBodyPart);
    }
  };

  // Administer medicine
  const administerMedicine = () => {
    if (!selectedMedicineType) return;
    
    const medicine = medicineTypes.find(m => m.id === selectedMedicineType);
    
    showNotification(`${data.translations?.ui_checkingInventoryFor || 'Checking inventory for'} ${medicine?.name}...`, 'fa-clock');
    
    // Send to backend for inventory check and treatment using proper FiveM NUI method
    try {
      fetch(`https://${(window as any).GetParentResourceName()}/medical-treatment`, {
        method: 'POST',
        headers: { 'Content-Type': 'application/json' },
        body: JSON.stringify({
          action: 'administer-medicine',
          data: {
            playerId: data.playerId,
            bodyPart: 'patient',
            itemType: selectedMedicineType,
            itemName: medicine?.itemname || medicine?.name || 'medicine',
            displayName: medicine?.name || 'Medicine'
          }
        })
      }).then(response => response.json()).then(result => {
        if (result.status === 'success') {
          showNotification(`Successfully administered ${medicine?.name}`, 'fa-check-circle');
          setSelectedMedicineType(null);
          
          // Add treatment to assessment log
          addTreatmentEntry(`Applied ${medicine?.name} for pain management`);
        } else {
          showNotification(result.message || `Failed to administer ${medicine?.name}`, 'fa-times-circle');
        }
      }).catch(error => {
        console.error('Medicine application failed:', error);
        showNotification('Medicine application failed', 'fa-times-circle');
      });
    } catch (error) {
      console.error('Failed to send medicine request:', error);
      // Fallback to simulate for web testing
      simulateBackendResponse('administer-medicine', medicine?.itemname || 'medicine', medicine?.name || 'Medicine');
    }
  };

  // Give injection
  const ui_giveInjection = () => {
    if (!selectedInjectionType || !selectedBodyPart) return;
    
    const injection = injectionTypes.find(i => i.id === selectedInjectionType);
    
    // Send to backend for inventory check and treatment
    window.postMessage({
      type: 'medical-treatment',
      action: 'give-injection',
      data: {
        playerId: data.playerId,
        bodyPart: selectedBodyPart,
        itemType: selectedInjectionType,
        itemName: injection?.itemname || injection?.name || 'injection',
        displayName: injection?.name || 'Injection'
      }
    }, '*');
    
    showNotification(`${data.translations?.ui_checkingInventoryFor || 'Checking inventory for'} ${injection?.name}...`, 'fa-clock');
    
    // Simulate backend response for testing in web
    simulateBackendResponse('give-injection', injection?.itemname || 'injection', injection?.name || 'Injection', selectedBodyPart);
  };

  // Body part inspection with detailed report generation
  const inspectBodyPart = (bodyPart: string) => {
    setSelectedBone(bodyPart);
    setInspectedBones(prev => new Set([...Array.from(prev), bodyPart]));
    
    // Get wound data for this body part
    const woundData = getWoundData(bodyPart);

    // Only discover injuries if they're significant enough to notice AND not a scar
    if (woundData && !woundData.isScar && ((woundData.painLevel || 0) > 3 || (woundData.bleedingLevel || 0) > 2)) {
      setDiscoveredInjuries(prev => ({ ...prev, [bodyPart]: woundData }));
    }
    
    // Check if all body parts have been inspected
    const allBodyParts = ['head', 'spine', 'upbody', 'lowbody', 'larm', 'rarm', 'lhand', 'rhand', 'lleg', 'rleg', 'lfoot', 'rfoot'];
    const newInspected = new Set([...Array.from(inspectedBones), bodyPart]);
    if (newInspected.size >= allBodyParts.length * 0.8) { // 80% threshold
      setHasInspectedFully(true);
    }
    
    // Generate detailed inspection report
    const generateDetailedReport = () => {
      if (!woundData) {
        return {
          boneIntegrity: data.translations?.ui_normalBoneIntegrity || 'Normal',
          softTissue: data.translations?.ui_noVisibleDamage || 'No visible damage',
          bloodFlow: data.translations?.ui_normalCirculationReport || 'Normal circulation',
          painResponse: data.translations?.ui_noSignificantPain || 'No significant pain response',
          swelling: data.translations?.ui_noneDetected || 'None detected',
          discoloration: data.translations?.ui_normalSkin || 'Normal skin tone',
          woundDescription: data.translations?.ui_noWoundsDetected || 'No wounds detected in this area',
          recommendation: data.translations?.ui_noImmediateTreatment || 'No immediate treatment required'
        };
      }

      // Check if this is a scar (healed wound) - display differently
      if (woundData.isScar) {
        const woundDesc = woundData.metadata?.description || 'Unknown injury';
        return {
          boneIntegrity: 'Healed - Scar tissue formed',
          softTissue: 'Scar tissue present from previous injury',
          bloodFlow: 'Normal circulation restored',
          painResponse: 'No active pain - fully healed',
          swelling: 'None - injury has healed',
          discoloration: 'Permanent scar tissue visible',
          woundDescription: `OLD HEALED INJURY: ${woundDesc}`,
          recommendation: 'No treatment required - wound has fully healed into scar tissue'
        };
      }

      const painLevel = woundData.painLevel || 0;
      const bleedingLevel = woundData.bleedingLevel || 0;
      
      // Get pain and bleeding descriptions from config
      const getPainDescription = (level: number): string => {
        if (level === 0) return 'No pain';
        if (data.injuryStates && data.injuryStates[level]) {
          return data.injuryStates[level].pain || `Pain level ${level}`;
        }
        return `Pain level ${level}`;
      };
      
      const getBleedingDescription = (level: number): string => {
        if (level === 0) return 'No bleeding';
        if (data.injuryStates && data.injuryStates[level]) {
          return data.injuryStates[level].bleeding || `Bleeding level ${level}`;
        }
        return `Bleeding level ${level}`;
      };
      
      const getTreatmentRecommendation = (painLvl: number, bleedingLvl: number): string => {
        // Handle different scenarios based on what's actually wrong
        if (bleedingLvl > 0 && painLvl > 0) {
          // Both bleeding and pain - use unifiedDesc from the higher level
          const maxLevel = Math.max(painLvl, bleedingLvl);
          if (data.injuryStates && data.injuryStates[maxLevel] && data.injuryStates[maxLevel].unifiedDesc) {
            return data.injuryStates[maxLevel].unifiedDesc;
          }
          return 'Combined pain and bleeding treatment needed';
        } else if (bleedingLvl > 0) {
          // Bleeding only - use bleedDesc
          if (data.injuryStates && data.injuryStates[bleedingLvl] && data.injuryStates[bleedingLvl].bleedDesc) {
            return data.injuryStates[bleedingLvl].bleedDesc;
          }
          // Fallback for bleeding-only scenarios
          if (bleedingLvl >= 8) return 'URGENT: Control bleeding immediately - life threatening';
          if (bleedingLvl >= 6) return 'Apply tourniquet or pressure bandage to stop bleeding';
          if (bleedingLvl >= 4) return 'Apply bandage to control bleeding';
          return 'Monitor bleeding, apply basic bandage if needed';
        } else if (painLvl > 0) {
          // Pain only - use painDesc
          if (data.injuryStates && data.injuryStates[painLvl] && data.injuryStates[painLvl].painDesc) {
            return data.injuryStates[painLvl].painDesc;
          }
          // Fallback for pain-only scenarios
          if (painLvl >= 8) return 'URGENT: Severe pain management required - administer strong painkillers';
          if (painLvl >= 6) return 'Significant pain management needed - use pain medication';
          if (painLvl >= 4) return 'Apply pain relief measures - basic painkillers recommended';
          return 'Monitor discomfort, rest and basic pain relief if needed';
        }
        
        return 'No immediate treatment required';
      };
      
      // Determine urgency level
      const getUrgencyLevel = (painLvl: number, bleedingLvl: number): string => {
        const maxLevel = Math.max(painLvl, bleedingLvl);
        if (data.injuryStates && data.injuryStates[maxLevel]) {
          return data.injuryStates[maxLevel].urgency || 'unknown';
        }
        if (maxLevel >= 8) return 'critical';
        if (maxLevel >= 6) return 'high';
        if (maxLevel >= 4) return 'medium';
        if (maxLevel >= 2) return 'low';
        return 'very low';
      };
      
      const totalSeverity = painLevel + (bleedingLevel * 2); // Bleeding is more severe
      const urgency = getUrgencyLevel(painLevel, bleedingLevel);
      
      return {
        boneIntegrity: painLevel > 8 ? (data.translations?.ui_possibleFracture || 'Possible fracture detected') : painLevel > 5 ? (data.translations?.ui_boneBruising || 'Bone bruising suspected') : (data.translations?.ui_normalBone || 'Normal'),
        softTissue: bleedingLevel > 0 ? `${getBleedingDescription(bleedingLevel)}` : painLevel > 0 ? `${data.translations?.ui_contusionsPresent || 'Contusions present'} (${getPainDescription(painLevel)})` : (data.translations?.ui_noVisibleDamage || 'No visible damage'),
        bloodFlow: bleedingLevel > 6 ? `${data.translations?.ui_activeBleeding || 'Active bleeding'}: ${getBleedingDescription(bleedingLevel)}` : bleedingLevel > 0 ? `${getBleedingDescription(bleedingLevel)} ${data.translations?.ui_bleedingObserved || 'observed'}` : (data.translations?.ui_normalCirculation || 'Normal circulation'),
        painResponse: painLevel > 0 ? `${data.translations?.ui_patientReports || 'Patient reports'}: ${getPainDescription(painLevel)}` : (data.translations?.ui_noSignificantPain || 'No significant pain response'),
        swelling: totalSeverity > 12 ? (data.translations?.ui_significantSwelling || 'Significant swelling present') : totalSeverity > 6 ? (data.translations?.ui_minorSwelling || 'Minor swelling detected') : (data.translations?.ui_noneDetected || 'None detected'),
        discoloration: bleedingLevel > 3 ? (data.translations?.ui_bloodPooling || 'Blood pooling visible') : painLevel > 5 ? (data.translations?.ui_bruisingDiscoloration || 'Bruising and discoloration') : (data.translations?.ui_normalSkin || 'Normal skin tone'),
        woundDescription: woundData.metadata?.description || (data.translations?.ui_noWoundDescription || 'No detailed wound description available'),
        recommendation: getTreatmentRecommendation(painLevel, bleedingLevel)
      };
    };

    const detailedReport = generateDetailedReport();
    setDetailedInspectionResults(prev => ({ ...prev, [bodyPart]: detailedReport }));

    // Add to medical assessment if injuries found (but skip scars - they're healed)
    if (woundData && !woundData.isScar && ((woundData.painLevel || 0) > 3 || (woundData.bleedingLevel || 0) > 2)) {
      const bodyPartName = getBodyPartName(bodyPart);
      const severity = woundData.severity || 0;
      const bleeding = woundData.bleeding || 0;

      if (severity > 70) {
        addAssessmentEntry(`${bodyPartName}: ${data.translations?.ui_criticalInjuryDetected || 'Critical injury detected - immediate attention required'}`);
      } else if (severity > 40) {
        addAssessmentEntry(`${bodyPartName}: ${data.translations?.ui_moderateInjuryFound || 'Moderate injury found - treatment recommended'}`);
      } else if (bleeding > 15) {
        addAssessmentEntry(`${bodyPartName}: ${data.translations?.ui_activeBleedingObserved || 'Active bleeding observed'}`);
      } else {
        addAssessmentEntry(`${bodyPartName}: ${data.translations?.ui_minorInjuryNoted || 'Minor injury noted'}`);
      }

      setDiscoveredInjuries(prev => ({ ...prev, [bodyPart]: woundData }));
    }
    
    // Send inspection data to server
    window.postMessage({ 
      type: 'inspect-body-part', 
      data: {
        playerId: data.playerId,
        bodyPart,
        woundData,
        detailedReport,
        patientName: data.playerName
      }
    }, '*');
  };

  // Medical actions
  const handleMedicalAction = (action: string, target?: string, extra?: any) => {
    // Use fetch() to properly communicate with Lua RegisterNUICallback
    fetch(`https://${(window as any).GetParentResourceName()}/medical-action`, {
      method: 'POST',
      headers: {
        'Content-Type': 'application/json'
      },
      body: JSON.stringify({
        action,
        target,
        extra,
        playerId: data.playerId,
        patientName: data.playerName
      })
    })
    .then(resp => resp.json())
    .then(result => {
      if (result.status === 'error') {
        console.error('[QC-AdvancedMedic] Medical action error:', result.message);
      }
    })
    .catch(err => {
      console.error('[QC-AdvancedMedic] Medical action failed:', err);
    });
  };

  // Render discovered wounds for assessment
  const renderDiscoveredWounds = () => {
    if (Object.keys(discoveredInjuries).length === 0) return <div className="no-visible-injuries">{data.translations?.ui_noInjuriesDiscovered || 'No injuries discovered yet'}</div>;

    const bodyPartNames = {
      'head': data.translations?.bodyPart_head || 'Head', 
      'spine': data.translations?.bodyPart_spine || 'Spine', 
      'upbody': data.translations?.bodyPart_upbody || 'Upper Body', 
      'lowbody': data.translations?.bodyPart_lowbody || 'Lower Body',
      'larm': data.translations?.bodyPart_larm || 'Left Arm', 
      'rarm': data.translations?.bodyPart_rarm || 'Right Arm', 
      'lhand': data.translations?.bodyPart_lhand || 'Left Hand', 
      'rhand': data.translations?.bodyPart_rhand || 'Right Hand',
      'lleg': data.translations?.bodyPart_lleg || 'Left Leg', 
      'rleg': data.translations?.bodyPart_rleg || 'Right Leg', 
      'lfoot': data.translations?.bodyPart_lfoot || 'Left Foot', 
      'rfoot': data.translations?.bodyPart_rfoot || 'Right Foot'
    };

    return (
      <div className="wounds-assessment">
        {Object.entries(discoveredInjuries).map(([bodyPart, wound]) => {
          const health = 100 - wound.severity;
          const bleeding = wound.bleeding || 0;
          
          // Only show visible injuries
          if (health > 70 && bleeding < 10) return null;

          const color = health >= 60 ? '#f39c12' : health >= 30 ? '#e67e22' : '#e74c3c';
          let condition = 'Normal';
          
          if (bleeding > 20) condition = 'Heavy Bleeding';
          else if (bleeding > 10) condition = 'Minor Bleeding';
          else if (health < 30) condition = 'Severely Wounded';
          else if (health < 50) condition = data.translations?.ui_injured || 'Injured';
          else if (health < 70) condition = 'Wounded';

          return (
            <div key={bodyPart} className="wound-item" style={{ display: 'flex', justifyContent: 'space-between', margin: '0.2vw 0', padding: '0.3vw' }}>
              <span style={{ color: 'white', fontSize: '0.7vw' }}>
                {bodyPartNames[bodyPart as keyof typeof bodyPartNames] || bodyPart}:
              </span>
              <span style={{ color, fontSize: '0.7vw' }}>{condition}</span>
            </div>
          );
        })}
      </div>
    );
  };

  return (
    <div className="medical-inspection-rightsidepanel" style={{ display: 'block' }}>
      {/* Left Side Action Buttons */}
      <div className="medic-action-sidebar">
        <div className={`medic-action-btn home-btn ${currentView === 'home' ? 'active' : ''}`} onClick={() => switchView('home')}>
          <i className="fas fa-home"></i>
          <div className="action-tooltip"></div>
        </div>
        
        <div className={`medic-action-btn ${currentView === 'bandage' ? 'active' : ''}`} onClick={() => switchView('bandage')}>
          <i className="fas fa-plus-circle"></i>
          <div className="action-tooltip"></div>
        </div>
        
        <div className={`medic-action-btn ${currentView === 'tourniquet' ? 'active' : ''}`} onClick={() => switchView('tourniquet')}>
          <i className="fas fa-compress"></i>
          <div className="action-tooltip"></div>
        </div>
        
        <div className={`medic-action-btn ${currentView === 'medicine' ? 'active' : ''}`} onClick={() => switchView('medicine')}>
          <i className="fas fa-pills"></i>
          <div className="action-tooltip"></div>
        </div>
        
        <div className={`medic-action-btn ${currentView === 'injection' ? 'active' : ''}`} onClick={() => switchView('injection')}>
          <i className="fas fa-syringe"></i>
          <div className="action-tooltip"></div>
        </div>
        
        <div className={`medic-action-btn ${currentView === 'body-inspection' ? 'active' : ''}`} onClick={() => switchView('body-inspection')}>
          <i className="fas fa-search"></i>
          <div className="action-tooltip"></div>
        </div>
        
        <div className={`medic-action-btn ${currentView === 'vitals' ? 'active' : ''}`} onClick={() => switchView('vitals')}>
          <i className="fas fa-heartbeat"></i>
          <div className="action-tooltip"></div>
        </div>
        
        <div className={`medic-action-btn ${currentView === 'doctors-bag' ? 'active' : ''}`} onClick={() => switchView('doctors-bag')}>
          <i className="fas fa-briefcase-medical"></i>
          <div className="action-tooltip">{data.translations?.ui_doctorsBag || "Doctor's Bag"}</div>
        </div>
      </div>

      <div className="rightsidepanel-container">
        {/* Panel Header */}
        <div className="rightsidepanel-header">
          <div className="panel-close-btn" onClick={onClose}>&times;</div>
          <div className="panel-title">
            <i className="fas fa-stethoscope"></i>
            {data.translations?.ui_medicalInspection || 'MEDICAL INSPECTION'}
          </div>
          <div className="panel-subtitle">{data.translations?.ui_patientMedicalAssessment || 'Patient Medical Assessment'}</div>
        </div>

        <div className="medic-inspection-content" ref={contentContainerRef}>
          {/* Render different views based on current selection */}
          {currentView === 'home' && (
            <>
              {/* Medic Info */}
              <div className="quick-patient-info">
                <div className="patient-name-large">Dr. {data.playerName || data.translations?.ui_unknownMedic || 'Unknown Medic'}</div>
                <div className="patient-id-small">
                  {data.translations?.ui_fieldPhysician || 'Field Physician - Medical Corps'}
                </div>
              </div>

              <div className="inspection-divider"></div>

              {/* Medical Kit Status */}
              <div className="blood-level-display">
                <div className="blood-header">
                  <i className="fas fa-briefcase-medical"></i>
                  <span>{data.translations?.ui_medicalBag || 'MEDICAL KIT STATUS'}</span>
                </div>
                <div style={{ padding: '1vw', textAlign: 'center' }}>
                  <div style={{ fontSize: '0.8vw', color: '#27ae60', marginBottom: '0.5vw' }}>
                    <i className="fas fa-check-circle" style={{ marginRight: '0.5vw' }}></i>
                    {data.translations?.tool_fieldSurgeryKit || 'Field Kit Ready'}
                  </div>
                  <div style={{ fontSize: '0.6vw', color: 'white' }}>
                    All medical instruments operational
                  </div>
                </div>
              </div>

              <div className="inspection-divider"></div>

              {/* Assessment Status */}
              <div className="medical-details-section">
                <div className="section-title">
                  <i className="fas fa-clipboard-list"></i>
                  <span>{data.translations?.ui_patientAssessment || 'PATIENT ASSESSMENT'}</span>
                </div>
                <div className="details-content">
                  {medicalAssessment.length === 0 ? (
                    <div style={{ textAlign: 'center', padding: '2vw', color: 'rgba(226, 199, 146, 0.6)' }}>
                      <i className="fas fa-search" style={{ fontSize: '1.5vw', marginBottom: '0.5vw' }}></i>
                      <div style={{ fontSize: '0.7vw', marginBottom: '0.3vw' }}>No assessment completed</div>
                      <div style={{ fontSize: '0.5vw' }}>Use body inspection and vitals to evaluate patient condition</div>
                    </div>
                  ) : (
                    <>
                      <div style={{ fontSize: '0.6vw', color: 'white', marginBottom: '0.8vw', fontStyle: 'italic' }}>
                        Medical assessment findings:
                      </div>
                      
                      {/* Assessment Findings */}
                      <div style={{ maxHeight: '18vw', overflowY: 'auto', marginBottom: '1vw' }}>
                        {medicalAssessment.map((finding, index) => (
                          <div key={index} style={{ 
                            fontSize: '0.8vw', 
                            color: 'white', 
                            marginBottom: '0.3vw',
                            padding: '0.4vw 0.8vw',
                            borderLeft: '2px solid white',
                            background: 'rgba(226, 199, 146, 0.05)'
                          }}>
                            • {finding}
                          </div>
                        ))}
                      </div>
                      
                      {/* Treatment Log */}
                      {treatmentsApplied.length > 0 && (
                        <>
                          <div style={{ fontSize: '0.6vw', color: 'white', marginBottom: '0.5vw', fontStyle: 'italic' }}>
                            {data.translations?.treatmentsApplied || 'Treatments Applied'}:
                          </div>
                          <div style={{ maxHeight: '8vw', overflowY: 'auto' }}>
                            {treatmentsApplied.map((treatment, index) => (
                              <div key={index} style={{ 
                                fontSize: '0.55vw', 
                                color: '#27ae60', 
                                marginBottom: '0.2vw',
                                padding: '0.2vw 0.5vw',
                                borderLeft: '2px solid #27ae60',
                                background: 'rgba(39, 174, 96, 0.05)'
                              }}>
                                • {treatment}
                              </div>
                            ))}
                          </div>
                        </>
                      )}
                    </>
                  )}
                </div>
              </div>
            </>
          )}

          {currentView === 'vitals' && (
            <div className="vitals-checking-view">
              <div className="section-title">
                <i className="fas fa-heartbeat"></i>
                <span>{data.translations?.vitalSignsChecking || 'VITAL SIGNS CHECKING'}</span>
              </div>
              
              {!ui_vitalsChecked ? (
                <div className="vitals-panel" style={{ textAlign: 'center', padding: '2vw' }}>
                  <div style={{ fontSize: '0.8vw', color: 'white', marginBottom: '1vw' }}>
                    <i className="fas fa-stethoscope" style={{ fontSize: '2vw', marginBottom: '0.5vw' }}></i>
                    <div>{data.translations?.placeStethoscope || "Place stethoscope on patient's chest"}</div>
                  </div>
                  
                  <div style={{ fontSize: '0.6vw', color: 'white', marginBottom: '1.5vw' }}>
                    {checkingVitals ? (data.translations?.listeningHeartbeat || 'Listening for heartbeat... Keep holding!') : (data.translations?.holdToCheckVitals || 'Hold the button below for 3 seconds to check vitals')}
                  </div>
                  
                  <div className="vitals-controls" style={{ display: 'flex', gap: '1vw', justifyContent: 'center' }}>
                    <button 
                      className="vitals-hold-btn"
                      onMouseDown={startVitalsCheck}
                      onMouseUp={stopVitalsCheck}
                      onMouseLeave={stopVitalsCheck}
                      style={{
                        background: checkingVitals ? '#f39c12' : 'white',
                        color: '#2c1810',
                        border: 'none',
                        padding: '0.8vw 1.5vw',
                        borderRadius: '0.3vw',
                        fontSize: '0.7vw',
                        cursor: 'pointer',
                        position: 'relative',
                        overflow: 'hidden'
                      }}
                    >
                      <i className="fas fa-hand-paper" style={{ marginRight: '0.5vw' }}></i>
                      {checkingVitals ? (data.translations?.checking || 'CHECKING...') : (data.translations?.holdToCheck || 'HOLD TO CHECK')}
                      {checkingVitals && (
                        <div style={{
                          position: 'absolute',
                          bottom: 0,
                          left: 0,
                          width: `${vitalsProgress}%`,
                          height: '100%',
                          background: 'rgba(39, 174, 96, 0.3)',
                          transition: 'width 0.1s ease'
                        }}></div>
                      )}
                    </button>
                    
                    <button 
                      onClick={() => switchView('home')}
                      style={{
                        background: 'transparent',
                        color: 'white',
                        border: '1px solid white',
                        padding: '0.8vw 1.5vw',
                        borderRadius: '0.3vw',
                        fontSize: '0.7vw',
                        cursor: 'pointer'
                      }}
                    >
                      <i className="fas fa-times" style={{ marginRight: '0.5vw' }}></i>
                      {data.translations?.cancel || 'CANCEL'}
                    </button>
                  </div>
                </div>
              ) : (
                <div className="vitals-results" style={{ padding: '1vw' }}>
                  <div className="section-title" style={{ marginBottom: '1vw' }}>
                    <i className="fas fa-check-circle" style={{ color: '#27ae60' }}></i>
                    <span>VITAL SIGNS RESULTS</span>
                  </div>
                  
                  <div style={{ display: 'flex', flexDirection: 'column', gap: '0.5vw' }}>
                    <div style={{ display: 'flex', justifyContent: 'space-between', padding: '0.3vw', background: 'rgba(226, 199, 146, 0.05)', borderRadius: '0.2vw' }}>
                      <span style={{ color: 'white', fontSize: '0.7vw' }}>Heart Rate:</span>
                      <span style={{ color: 'white', fontSize: '0.7vw', fontWeight: 'bold' }}>{vitals.heartRate} BPM</span>
                    </div>
                    <div style={{ display: 'flex', justifyContent: 'space-between', padding: '0.3vw', background: 'rgba(226, 199, 146, 0.05)', borderRadius: '0.2vw' }}>
                      <span style={{ color: 'white', fontSize: '0.7vw' }}>Temperature:</span>
                      <span style={{ color: 'white', fontSize: '0.7vw', fontWeight: 'bold' }}>{data.vitals?.temperature || '98.6'} °F</span>
                    </div>
                    <div style={{ display: 'flex', justifyContent: 'space-between', padding: '0.3vw', background: 'rgba(226, 199, 146, 0.05)', borderRadius: '0.2vw' }}>
                      <span style={{ color: 'white', fontSize: '0.7vw' }}>Breathing:</span>
                      <span style={{ color: 'white', fontSize: '0.7vw', fontWeight: 'bold' }}>{data.vitals?.breathing || '16'} /min</span>
                    </div>
                    <div style={{ display: 'flex', justifyContent: 'space-between', padding: '0.3vw', background: 'rgba(226, 199, 146, 0.05)', borderRadius: '0.2vw' }}>
                      <span style={{ color: 'white', fontSize: '0.7vw' }}>Status:</span>
                      <span style={{ color: vitals.statusColor, fontSize: '0.7vw', fontWeight: 'bold' }}>{vitals.status}</span>
                    </div>
                    
                    {/* Vitals Description */}
                    {vitals.description && (
                      <div style={{ padding: '0.5vw', background: 'rgba(226, 199, 146, 0.1)', borderRadius: '0.2vw', marginTop: '0.5vw' }}>
                        <div style={{ color: 'white', fontSize: '0.6vw', fontWeight: 'bold', marginBottom: '0.2vw' }}>Clinical Assessment:</div>
                        <div style={{ color: 'white', fontSize: '0.6vw', lineHeight: '1.3', fontStyle: 'italic' }}>{vitals.description}</div>
                      </div>
                    )}
                  </div>
                </div>
              )}
            </div>
          )}

          {currentView === 'body-inspection' && (
            <div className="body-inspection-view">
              <div className="section-title">
                <i className="fas fa-search-plus"></i>
                <span>{data.translations?.ui_bodyInspectionTitle || 'BODY INSPECTION MODE'}</span>
              </div>
              
              <div style={{ fontSize: '0.6vw', color: 'white', marginBottom: '0.8vw', fontStyle: 'italic' }}>
                Click on body parts to perform detailed inspection
              </div>
              
              {/* Body parts grid */}
              <div className="body-parts-grid" style={{ display: 'grid', gridTemplateColumns: 'repeat(2, 1fr)', gap: '0.3vw', marginBottom: '1vw' }}>
                {['head', 'spine', 'upbody', 'lowbody', 'larm', 'rarm', 'lhand', 'rhand', 'lleg', 'rleg', 'lfoot', 'rfoot'].map(bodyPart => {
                  const wound = getWoundData(bodyPart);
                  const isInspected = inspectedBones.has(bodyPart);
                  const isSelected = selectedBone === bodyPart;
                  
                  return (
                    <div 
                      key={bodyPart}
                      className={`body-part-item ${isInspected ? 'inspected' : ''} ${isSelected ? 'selected' : ''}`}
                      onClick={() => inspectBodyPart(bodyPart)}
                      style={{
                        padding: '0.4vw',
                        background: isSelected ? 'rgba(226, 199, 146, 0.2)' : isInspected ? 'rgba(226, 199, 146, 0.1)' : 'rgba(0,0,0,0.1)',
                        border: `1px solid ${isSelected ? 'white' : 'rgba(226, 199, 146, 0.3)'}`,
                        borderRadius: '0.2vw',
                        cursor: 'pointer',
                        fontSize: '0.6vw',
                        color: 'white',
                        textAlign: 'center',
                        position: 'relative'
                      }}
                    >
                      {bodyPart.replace(/([A-Z])/g, ' $1').replace(/^./, str => str.toUpperCase())}
                      {wound && ((wound.painLevel || 0) > 3 || (wound.bleedingLevel || 0) > 2) && (
                        <div style={{ 
                          position: 'absolute', 
                          top: '2px', 
                          right: '2px', 
                          width: '6px', 
                          height: '6px', 
                          background: (wound.bleedingLevel || 0) >= 6 ? '#e74c3c' : '#f39c12', 
                          borderRadius: '50%' 
                        }}></div>
                      )}
                      {isInspected && <i className="fas fa-check" style={{ position: 'absolute', bottom: '2px', right: '2px', fontSize: '0.5vw', color: '#27ae60' }}></i>}
                    </div>
                  );
                })}
              </div>

              {/* Detailed inspection results */}
              {selectedBone && detailedInspectionResults[selectedBone] && (
                <div className="bone-inspection-details" style={{ padding: '0.8vw', background: 'rgba(226, 199, 146, 0.05)', borderRadius: '0.3vw', maxHeight: '20vw', overflowY: 'auto' }}>
                  <h4 style={{ color: 'white', fontSize: '0.8vw', marginBottom: '0.5vw' }}>
                    Detailed Inspection: {selectedBone.toUpperCase()}
                  </h4>
                  <div className="detailed-results" style={{ fontSize: '0.55vw', lineHeight: '1.4' }}>
                    {Object.entries(detailedInspectionResults[selectedBone]).map(([key, value]) => (
                      <div key={key} style={{ marginBottom: '0.4vw', display: 'flex', flexDirection: 'column' }}>
                        <span style={{ color: 'white', fontWeight: 'bold', textTransform: 'capitalize' }}>
                          {key.replace(/([A-Z])/g, ' $1')}:
                        </span>
                        <span style={{ 
                          color: key === 'recommendation' && (value as string).includes('URGENT') ? '#e74c3c' : 
                                 key === 'recommendation' && (value as string).includes('Treatment') ? '#f39c12' : 
                                 key === 'woundDescription' ? '#E2C792' : 'white',
                          marginLeft: '0.5vw',
                          fontStyle: key === 'recommendation' || key === 'woundDescription' ? 'italic' : 'normal',
                          lineHeight: key === 'woundDescription' ? '1.4' : 'normal'
                        }}>
                          {value as string}
                        </span>
                      </div>
                    ))}
                  </div>
                </div>
              )}
            </div>
          )}

          {currentView === 'bandage' && (
            <div className="bandage-view">
              <div className="section-title">
                <i className="fas fa-plus-circle"></i>
                <span>{data.translations?.ui_applyBandageTitle || 'APPLY BANDAGE'}</span>
              </div>

              {/* Bandage Safety Information - TOP PRIORITY */}
              <div className="medical-details-section" style={{ marginBottom: '1vw' }}>
                <div className="section-title" style={{ fontSize: '0.7vw', marginBottom: '0.5vw' }}>
                  <i className="fas fa-exclamation-triangle"></i>
                  <span>{data.translations?.ui_infectionControl || 'INFECTION CONTROL'}</span>
                </div>
                <div className="infection-warning-section" style={{
                  background: 'rgba(139, 169, 85, 0.25)',
                  border: '0.05vw solid rgba(139, 169, 85, 0.4)',
                  borderRadius: '0.3vw',
                  padding: '0.8vw',
                  boxShadow: '0 0 0.8vw rgba(139, 169, 85, 0.3)'
                }}>
                  <div style={{ fontSize: '0.6vw', color: 'white', marginBottom: '0.5vw' }}>
                    • {data.translations?.ui_cleanWound || 'Clean wound thoroughly before applying any bandage'}
                  </div>
                  <div style={{ fontSize: '0.6vw', color: 'white', marginBottom: '0.5vw' }}>
                    • {data.translations?.ui_changeBandages || 'Change bandages regularly to prevent infection'}
                  </div>
                  <div style={{ fontSize: '0.6vw', color: 'white' }}>
                    • {data.translations?.ui_watchInfection || 'Watch for signs of infection: swelling, pus, unusual odor'}
                  </div>
                </div>
              </div>
              
              {/* Patient Conditions */}
              <div className="medical-details-section" style={{ marginBottom: '1vw' }}>
                <div className="section-title" style={{ fontSize: '0.7vw', marginBottom: '0.5vw' }}>
                  <i className="fas fa-user-injured"></i>
                  <span>{data.translations?.ui_bleedingConditions || 'BLEEDING CONDITIONS (Light/Moderate)'}</span>
                </div>
                <div className="treatment-grid">
                  {Object.entries(discoveredInjuries).filter(([bodyPart, _]) => needsBandage(bodyPart)).map(([bodyPart, discoveredWound]) => {
                    if (!discoveredWound) return null;
                    
                    const painLevel = discoveredWound.painLevel || 0;
                    const bleedingLevel = discoveredWound.bleedingLevel || 0;
                    const totalSeverity = painLevel + (bleedingLevel * 2);
                    
                    return (
                      <div 
                        key={bodyPart} 
                        className={`treatment-option ${selectedBodyPart === bodyPart ? 'selected' : ''}`}
                        onClick={() => !isBandaged(bodyPart) ? setSelectedBodyPart(bodyPart) : null}
                        style={{
                          padding: '0.5vw',
                          margin: '0.2vw 0',
                          background: selectedBodyPart === bodyPart ? 'rgba(226, 199, 146, 0.2)' : 'rgba(226, 199, 146, 0.05)',
                          border: `1px solid ${selectedBodyPart === bodyPart ? 'white' : 'rgba(226, 199, 146, 0.3)'}`,
                          borderRadius: '0.2vw',
                          cursor: isBandaged(bodyPart) ? 'default' : 'pointer',
                          display: 'flex',
                          justifyContent: 'space-between',
                          alignItems: 'center',
                          opacity: isBandaged(bodyPart) ? 0.7 : 1
                        }}
                      >
                        <span style={{ color: 'white', fontSize: '0.7vw' }}>
                          {getBodyPartName(bodyPart).toUpperCase()}
                        </span>
                        <span style={{ 
                          color: isBandaged(bodyPart) ? '#27ae60' : bleedingLevel >= 6 ? '#e74c3c' : totalSeverity > 6 ? '#f39c12' : '#e67e22',
                          fontSize: '0.6vw'
                        }}>
                          {isBandaged(bodyPart) ? (data.translations?.ui_bandaged || 'Bandaged') : bleedingLevel >= 6 ? (data.translations?.ui_critical || 'Critical') : totalSeverity > 6 ? (data.translations?.ui_injured || 'Injured') : (data.translations?.ui_bleeding || 'Bleeding')}
                        </span>
                      </div>
                    );
                  })}
                  {Object.entries(discoveredInjuries).filter(([bodyPart, _]) => needsBandage(bodyPart)).length === 0 && (
                    <div style={{ color: 'rgba(255, 255, 255, 0.6)', fontSize: '0.6vw', fontStyle: 'italic', textAlign: 'center', padding: '1vw' }}>
                      {Object.keys(discoveredInjuries).length === 0 
                        ? (data.translations?.ui_noWoundsDiscovered || 'No wounds discovered yet. Perform body inspection to identify bleeding wounds.') 
                        : (data.translations?.ui_noLightBleedingWounds || 'No light/moderate bleeding wounds discovered (requires bleeding level 1-6).')}
                    </div>
                  )}
                </div>
              </div>

              {/* Available Bandages */}
              <div className="medical-details-section" style={{ marginBottom: '1vw' }}>
                <div className="section-title" style={{ fontSize: '0.7vw', marginBottom: '0.5vw' }}>
                  <i className="fas fa-briefcase"></i>
                  <span>{data.translations?.ui_availiableBandages || 'AVAILABLE BANDAGES'}</span>
                </div>
                <div className="bandage-selection-grid" style={{ display: 'flex', flexWrap: 'wrap', gap: '0.4vw' }}>
                  {bandageTypes.map((bandage) => (
                    <div 
                      key={bandage.id}
                      className={`bandage-type ${selectedBandageType === bandage.id ? 'selected' : ''}`}
                      onClick={() => setSelectedBandageType(bandage.id)}
                      style={{
                        padding: '0.8vw',
                        height: 'auto',
                        background: selectedBandageType === bandage.id ? 'rgba(226, 199, 146, 0.15)' : 'rgba(0, 0, 0, 0.2)',
                        border: `1px solid ${selectedBandageType === bandage.id ? 'white' : 'rgba(226, 199, 146, 0.4)'}`,
                        borderRadius: '0.3vw',
                        cursor: 'pointer',
                        display: 'flex',
                        alignItems: 'center',
                        transition: 'background 0.2s ease',
                        flex: '0 0 calc(50% - 0.2vw)',
                        boxSizing: 'border-box'
                      }}
                    >
                      <div style={{ display: 'flex', flexDirection: 'column', alignItems: 'center', textAlign: 'center', width: '100%' }}>
                        <i className={`fas ${bandage.icon}`} style={{ 
                          fontSize: '1.8vw', 
                          color: 'white', 
                          marginBottom: '0.3vw'
                        }}></i>
                        <div style={{ color: 'white', fontSize: '0.8vw', fontWeight: 'bold', marginBottom: '0.2vw' }}>{bandage.name}</div>
                        <div style={{ color: 'rgba(226, 199, 146, 0.9)', fontSize: '0.65vw', lineHeight: '1.2' }}>{bandage.desc}</div>
                      </div>
                    </div>
                  ))}
                </div>
              </div>

              {/* Apply Button */}
              {selectedBandageType && selectedBodyPart && (
                <div style={{ textAlign: 'center', marginTop: '1vw' }}>
                  <button 
                    onClick={ui_applyBandage}
                    style={{
                      backgroundImage: 'url("./static/media/selection_box_bg_1d.db795b7cbe6db75cb337.png")',
                      backgroundSize: 'cover',
                      backgroundPosition: 'center',
                      color: 'white',
                      border: 'none',
                      padding: '0.8vw 2vw',
                      borderRadius: '0.3vw',
                      fontSize: '0.7vw',
                      cursor: 'pointer',
                      fontWeight: 'bold'
                    }}
                  >
                    <i className="fas fa-plus" style={{ marginRight: '0.5vw' }}></i>
                    APPLY TREATMENT
                  </button>
                </div>
              )}
            </div>
          )}

          {currentView === 'tourniquet' && (
            <div className="tourniquet-view">
              <div className="section-title">
                <i className="fas fa-compress"></i>
                <span>{data.translations?.ui_applyTourniquetTitle || 'APPLY TOURNIQUET'}</span>
              </div>

              {/* Tourniquet Safety Information - TOP PRIORITY */}
              <div className="medical-details-section" style={{ marginBottom: '1vw' }}>
                <div className="section-title" style={{ fontSize: '0.7vw', marginBottom: '0.5vw' }}>
                  <i className="fas fa-exclamation-triangle"></i>
                  <span>{data.translations?.ui_tourniquetSafety || 'TOURNIQUET SAFETY'}</span>
                </div>
                <div className="warning-notes-section">
                  <div style={{ fontSize: '0.6vw', color: 'white', marginBottom: '0.5vw' }}>
                    • {data.translations?.ui_applyProximal || 'Apply proximal to bleeding source, never over joints'}
                  </div>
                  <div style={{ fontSize: '0.6vw', color: 'white', marginBottom: '0.5vw' }}>
                    • {data.translations?.ui_tightenUntilStop || 'Tighten until bleeding stops - document application time'}
                  </div>
                  <div style={{ fontSize: '0.6vw', color: 'white' }}>
                    • {data.translations?.ui_riskLimbLoss || 'Risk of limb loss if left on too long - monitor closely'}
                  </div>
                </div>
              </div>
              
              {/* Patient Conditions */}
              <div className="medical-details-section" style={{ marginBottom: '1vw' }}>
                <div className="section-title" style={{ fontSize: '0.7vw', marginBottom: '0.5vw' }}>
                  <i className="fas fa-user-injured"></i>
                  <span>{data.translations?.ui_severeBleedingConditions || 'SEVERE BLEEDING CONDITIONS'}</span>
                </div>
                <div className="treatment-grid">
                  {Object.entries(discoveredInjuries).filter(([bodyPart, _]) => needsTourniquet(bodyPart)).map(([bodyPart, discoveredWound]) => {
                    if (!discoveredWound) return null;
                    
                    const bleedingLevel = discoveredWound.bleedingLevel || 0;
                    
                    return (
                      <div 
                        key={bodyPart} 
                        className={`treatment-option ${selectedBodyPart === bodyPart ? 'selected' : ''}`}
                        onClick={() => !isTourniqueted(bodyPart) ? setSelectedBodyPart(bodyPart) : null}
                        style={{
                          padding: '0.5vw',
                          margin: '0.2vw 0',
                          background: selectedBodyPart === bodyPart ? 'rgba(226, 199, 146, 0.2)' : 'rgba(226, 199, 146, 0.05)',
                          border: `1px solid ${selectedBodyPart === bodyPart ? 'white' : 'rgba(226, 199, 146, 0.3)'}`,
                          borderRadius: '0.2vw',
                          cursor: isTourniqueted(bodyPart) ? 'default' : 'pointer',
                          display: 'flex',
                          justifyContent: 'space-between',
                          alignItems: 'center',
                          opacity: isTourniqueted(bodyPart) ? 0.7 : 1
                        }}
                      >
                        <span style={{ color: 'white', fontSize: '0.7vw' }}>
                          {getBodyPartName(bodyPart).toUpperCase()}
                        </span>
                        <span style={{ 
                          color: isTourniqueted(bodyPart) ? '#27ae60' : bleedingLevel > 8 ? '#e74c3c' : '#f39c12',
                          fontSize: '0.6vw'
                        }}>
                          {isTourniqueted(bodyPart) ? (data.translations?.ui_tourniqueted || 'Tourniqueted') : bleedingLevel > 8 ? (data.translations?.ui_severeBleeding || 'Severe Bleeding') : (data.translations?.ui_heavyBleeding || 'Heavy Bleeding')}
                        </span>
                      </div>
                    );
                  })}
                  {Object.entries(discoveredInjuries).filter(([bodyPart, _]) => needsTourniquet(bodyPart)).length === 0 && (
                    <div style={{ color: 'rgba(255, 255, 255, 0.6)', fontSize: '0.6vw', fontStyle: 'italic', textAlign: 'center', padding: '1vw' }}>
                      {Object.keys(discoveredInjuries).length === 0 
                        ? (data.translations?.ui_noSevereBleedingDiscovered || 'No wounds discovered yet. Perform body inspection to identify severe bleeding.') 
                        : (data.translations?.ui_noSevereBleedingWounds || 'No severe bleeding wounds discovered (requires bleeding level 7+).')}
                    </div>
                  )}
                </div>
              </div>

              {/* Available Tourniquets */}
              <div className="medical-details-section" style={{ marginBottom: '1vw' }}>
                <div className="section-title" style={{ fontSize: '0.7vw', marginBottom: '0.5vw' }}>
                  <i className="fas fa-briefcase"></i>
                  <span>{data.translations?.ui_availableTourniquets || 'AVAILABLE TOURNIQUETS'}</span>
                </div>
                <div className="tourniquet-selection-grid" style={{ display: 'flex', flexWrap: 'wrap', gap: '0.4vw' }}>
                  {tourniquetTypes.map((tourniquet) => (
                    <div 
                      key={tourniquet.id}
                      className={`tourniquet-type ${selectedTourniquetType === tourniquet.id ? 'selected' : ''}`}
                      onClick={() => setSelectedTourniquetType(tourniquet.id)}
                      style={{
                        padding: '0.8vw',
                        height: 'auto',
                        background: selectedTourniquetType === tourniquet.id ? 'rgba(226, 199, 146, 0.15)' : 'rgba(0, 0, 0, 0.2)',
                        border: `1px solid ${selectedTourniquetType === tourniquet.id ? 'white' : 'rgba(226, 199, 146, 0.4)'}`,
                        borderRadius: '0.3vw',
                        cursor: 'pointer',
                        display: 'flex',
                        alignItems: 'center',
                        transition: 'background 0.2s ease',
                        flex: '0 0 calc(50% - 0.2vw)',
                        boxSizing: 'border-box'
                      }}
                    >
                      <div style={{ display: 'flex', flexDirection: 'column', alignItems: 'center', textAlign: 'center', width: '100%' }}>
                        <i className={`fas ${tourniquet.icon}`} style={{ 
                          fontSize: '1.8vw', 
                          color: 'white', 
                          marginBottom: '0.3vw'
                        }}></i>
                        <div style={{ color: 'white', fontSize: '0.8vw', fontWeight: 'bold', marginBottom: '0.2vw' }}>{tourniquet.name}</div>
                        <div style={{ color: 'rgba(226, 199, 146, 0.9)', fontSize: '0.65vw', lineHeight: '1.2' }}>{tourniquet.desc}</div>
                      </div>
                    </div>
                  ))}
                </div>
              </div>

              {/* Apply Button */}
              {selectedTourniquetType && selectedBodyPart && (
                <div style={{ textAlign: 'center', marginTop: '1vw' }}>
                  <button 
                    onClick={ui_applyTourniquet}
                    style={{
                      backgroundImage: 'url("./static/media/selection_box_bg_1d.db795b7cbe6db75cb337.png")',
                      backgroundSize: 'cover',
                      backgroundPosition: 'center',
                      color: 'white',
                      border: 'none',
                      padding: '0.8vw 2vw',
                      borderRadius: '0.3vw',
                      fontSize: '0.7vw',
                      cursor: 'pointer',
                      fontWeight: 'bold'
                    }}
                  >
                    <i className="fas fa-compress" style={{ marginRight: '0.5vw' }}></i>
                    APPLY TOURNIQUET
                  </button>
                </div>
              )}
            </div>
          )}

          {currentView === 'doctors-bag' && (
            <div className="doctors-bag-view">
              <div className="section-title" style={{ fontSize: '1.2vw', padding: '1.2vw', marginBottom: '1vw' }}>
                <i className="fas fa-briefcase-medical" style={{ fontSize: '1.4vw', marginRight: '0.5vw' }}></i>
                <span>{data.translations?.ui_medicalBag || 'MEDICAL BAG'}</span>
              </div>
              <div style={{ fontSize: '0.6vw', color: 'white', marginBottom: '1vw', fontStyle: 'italic' }}>
                {data.translations?.ui_wildWestMedical || 'Wild West medical tools and supplies'}
              </div>
              <div className="medical-tools-grid">
                {[
                  { name: data.translations?.stethoscope || 'Stethoscope', icon: 'fa-stethoscope', action: 'stethoscope', desc: data.translations?.stethoscopeDesc || 'Check heart and lung sounds' },
                  { name: data.translations?.thermometer || 'Thermometer', icon: 'fa-thermometer-half', action: 'thermometer', desc: data.translations?.thermometerDesc || 'Measure body temperature' },
                  { name: data.translations?.laudanum || 'Laudanum', icon: 'fa-prescription-bottle', action: 'laudanum', desc: data.translations?.laudanumDesc || 'Opium-based painkiller' },
                  { name: data.translations?.whiskey || 'Whiskey', icon: 'fa-wine-bottle', action: 'whiskey', desc: data.translations?.whiskeyDesc || 'Antiseptic and anesthetic' },
                  { name: data.translations?.fieldSurgeryKit || 'Field Surgery Kit', icon: 'fa-first-aid', action: 'field-kit', desc: data.translations?.fieldSurgeryKitDesc || 'Emergency surgical tools' },
                  { name: data.translations?.smellingSalts || 'Smelling Salts', icon: 'fa-vial', action: 'smelling-salts', desc: data.translations?.smellingSaltsDesc || 'Revive unconscious patients' }
                ].map((tool, index) => (
                  <div 
                    key={index}
                    className="medical-tool"
                    onClick={() => handleMedicalAction('use-tool', tool.action)}
                    style={{
                      padding: '0.8vw',
                      marginBottom: '0.5vw',
                      background: 'rgba(226, 199, 146, 0.05)',
                      border: '1px solid rgba(226, 199, 146, 0.3)',
                      borderRadius: '0.3vw',
                      cursor: 'pointer',
                      transition: 'background 0.2s ease'
                    }}
                    onMouseEnter={(e) => e.currentTarget.style.background = 'rgba(226, 199, 146, 0.1)'}
                    onMouseLeave={(e) => e.currentTarget.style.background = 'rgba(226, 199, 146, 0.05)'}
                  >
                    <div style={{ display: 'flex', alignItems: 'center', marginBottom: '0.2vw' }}>
                      <i className={`fas ${tool.icon}`} style={{ marginRight: '0.5vw', fontSize: '1vw', color: 'white' }}></i>
                      <span style={{ fontSize: '0.7vw', color: 'white', fontWeight: 'bold' }}>{tool.name}</span>
                    </div>
                    <div style={{ fontSize: '0.5vw', color: 'rgba(226, 199, 146, 0.7)', marginLeft: '1.5vw' }}>
                      {tool.desc}
                    </div>
                  </div>
                ))}
              </div>
            </div>
          )}

          {currentView === 'medicine' && (
            <div className="medicine-view">
              <div className="section-title">
                <i className="fas fa-pills"></i>
                <span>{data.translations?.ui_administerMedicine || 'ADMINISTER MEDICINE'}</span>
              </div>

              {/* Medicine Safety Information - TOP PRIORITY */}
              <div className="medical-details-section" style={{ marginBottom: '1vw' }}>
                <div className="section-title" style={{ fontSize: '0.7vw', marginBottom: '0.5vw' }}>
                  <i className="fas fa-exclamation-triangle"></i>
                  <span>{data.translations?.ui_administrationNotes || 'ADMINISTRATION NOTES'}</span>
                </div>
                <div className="warning-notes-section">
                  <div style={{ fontSize: '0.6vw', color: 'white', marginBottom: '0.5vw' }}>
                    • {data.translations?.ui_ensureSwallow || 'Ensure patient can swallow before administering oral medications'}
                  </div>
                  <div style={{ fontSize: '0.6vw', color: 'white', marginBottom: '0.5vw' }}>
                    • {data.translations?.ui_monitorReactions || 'Monitor patient for adverse reactions after administration'}
                  </div>
                  <div style={{ fontSize: '0.6vw', color: 'white' }}>
                    • {data.translations?.ui_drowsinessWarning || 'Some medicines may cause drowsiness or altered consciousness'}
                  </div>
                </div>
              </div>
              
              {/* Patient Pain Conditions */}
              <div className="medical-details-section" style={{ marginBottom: '1vw' }}>
                <div className="section-title" style={{ fontSize: '0.7vw', marginBottom: '0.5vw' }}>
                  <i className="fas fa-user-injured"></i>
                  <span>{data.translations?.ui_painConditions || 'PAIN CONDITIONS'}</span>
                </div>
                <div className="treatment-grid">
                  {Object.entries(discoveredInjuries).filter(([bodyPart, _]) => needsMedicine(bodyPart)).map(([bodyPart, discoveredWound]) => {
                    if (!discoveredWound) return null;
                    
                    const painLevel = discoveredWound.painLevel || 0;
                    const bleedingLevel = discoveredWound.bleedingLevel || 0;
                    
                    return (
                      <div 
                        key={bodyPart} 
                        className={`treatment-option ${selectedBodyPart === bodyPart ? 'selected' : ''}`}
                        onClick={() => setSelectedBodyPart(bodyPart)}
                        style={{
                          padding: '0.6vw', 
                          background: selectedBodyPart === bodyPart ? 'rgba(226, 199, 146, 0.15)' : 'rgba(0, 0, 0, 0.2)',
                          border: `1px solid ${selectedBodyPart === bodyPart ? 'white' : 'rgba(226, 199, 146, 0.4)'}`,
                          borderRadius: '0.3vw',
                          cursor: 'pointer',
                          display: 'flex',
                          flexDirection: 'column',
                          alignItems: 'center',
                          textAlign: 'center',
                          transition: 'background 0.2s ease',
                          margin: '0.2vw'
                        }}
                      >
                        <span style={{ color: 'white', fontSize: '0.7vw' }}>
                          {getBodyPartName(bodyPart).toUpperCase()}
                        </span>
                        <span style={{ 
                          color: painLevel >= 8 ? '#e74c3c' : painLevel >= 5 ? '#f39c12' : '#27ae60',
                          fontSize: '0.6vw'
                        }}>
                          {painLevel >= 8 ? (data.translations?.ui_severePain || 'Severe Pain') : painLevel >= 5 ? (data.translations?.ui_moderatePain || 'Moderate Pain') : (data.translations?.ui_mildPain || 'Mild Pain')}
                        </span>
                        {bleedingLevel > 0 && (
                          <span style={{ color: '#f39c12', fontSize: '0.5vw' }}>
                            + Bleeding ({bleedingLevel})
                          </span>
                        )}
                      </div>
                    );
                  })}
                  {Object.entries(discoveredInjuries).filter(([bodyPart, _]) => needsMedicine(bodyPart)).length === 0 && (
                    <div style={{ color: 'rgba(255, 255, 255, 0.6)', fontSize: '0.6vw', fontStyle: 'italic', textAlign: 'center', padding: '1vw' }}>
                      {Object.keys(discoveredInjuries).length === 0 
                        ? (data.translations?.ui_noWoundsDiscovered || 'No wounds discovered yet. Perform body inspection to identify pain conditions.') 
                        : (data.translations?.ui_noPainConditions || 'No pain conditions discovered (requires pain level 1+).')}
                    </div>
                  )}
                </div>
              </div>

              {/* Available Medicines */}
              <div className="medical-details-section" style={{ marginBottom: '1vw' }}>
                <div className="section-title" style={{ fontSize: '0.7vw', marginBottom: '0.5vw' }}>
                  <i className="fas fa-briefcase"></i>
                  <span>{data.translations?.ui_availableMedicine || 'AVAILABLE MEDICINES'}</span>
                </div>
                <div className="medicine-selection-grid" style={{ display: 'flex', flexWrap: 'wrap', gap: '0.4vw' }}>
                  {medicineTypes.map((medicine) => (
                    <div 
                      key={medicine.id}
                      className={`medicine-type ${selectedMedicineType === medicine.id ? 'selected' : ''}`}
                      onClick={() => setSelectedMedicineType(medicine.id)}
                      style={{
                        padding: '0.8vw',
                        height: 'auto',
                        background: selectedMedicineType === medicine.id ? 'rgba(226, 199, 146, 0.15)' : 'rgba(0, 0, 0, 0.2)',
                        border: `1px solid ${selectedMedicineType === medicine.id ? 'white' : 'rgba(226, 199, 146, 0.4)'}`,
                        borderRadius: '0.3vw',
                        cursor: 'pointer',
                        display: 'flex',
                        alignItems: 'center',
                        flex: '0 0 calc(50% - 0.2vw)',
                        boxSizing: 'border-box',
                        transition: 'background 0.2s ease'
                      }}
                    >
                      <div style={{ display: 'flex', flexDirection: 'column', alignItems: 'center', textAlign: 'center', width: '100%' }}>
                        <i className={`fas ${medicine.icon}`} style={{ 
                          fontSize: '1.8vw', 
                          color: 'white', 
                          marginBottom: '0.3vw'
                        }}></i>
                        <div style={{ color: 'white', fontSize: '0.8vw', fontWeight: 'bold', marginBottom: '0.2vw' }}>{medicine.name}</div>
                        <div style={{ color: 'rgba(226, 199, 146, 0.9)', fontSize: '0.65vw', lineHeight: '1.2' }}>{medicine.desc}</div>
                      </div>
                    </div>
                  ))}
                </div>
              </div>


              {/* Administer Button */}
              {selectedMedicineType && (
                <div style={{ textAlign: 'center', marginTop: '1vw' }}>
                  <button 
                    onClick={administerMedicine}
                    style={{
                      backgroundImage: 'url("./static/media/selection_box_bg_1d.db795b7cbe6db75cb337.png")',
                      backgroundSize: 'cover',
                      backgroundPosition: 'center',
                      color: 'white',
                      border: 'none',
                      padding: '0.8vw 2vw',
                      borderRadius: '0.3vw',
                      fontSize: '0.7vw',
                      cursor: 'pointer',
                      fontWeight: 'bold'
                    }}
                  >
                    <i className="fas fa-pills" style={{ marginRight: '0.5vw' }}></i>
                    {data.translations?.ui_administerMedicine || 'ADMINISTER MEDICINE'}
                  </button>
                </div>
              )}
            </div>
          )}

          {currentView === 'injection' && (
            <div className="injection-view">
              <div className="section-title">
                <i className="fas fa-syringe"></i>
                <span>{data.translations?.ui_giveInjectionTitle || 'GIVE INJECTION'}</span>
              </div>

              {/* Injection Safety Information - TOP PRIORITY */}
              <div className="medical-details-section" style={{ marginBottom: '1vw' }}>
                <div className="section-title" style={{ fontSize: '0.7vw', marginBottom: '0.5vw' }}>
                  <i className="fas fa-exclamation-triangle"></i>
                  <span>{data.translations?.ui_injectionSafety || 'INJECTION SAFETY'}</span>
                </div>
                <div className="warning-notes-section">
                  <div style={{ fontSize: '0.6vw', color: 'white', marginBottom: '0.5vw' }}>
                    • {data.translations?.ui_sterilizeSite || 'Sterilize injection site before administration'}
                  </div>
                  <div style={{ fontSize: '0.6vw', color: 'white', marginBottom: '0.5vw' }}>
                    • {data.translations?.ui_properTechnique || 'Use proper injection technique to avoid nerve damage'}
                  </div>
                  <div style={{ fontSize: '0.6vw', color: 'white' }}>
                    • {data.translations?.ui_monitorAllergic || 'Monitor for immediate allergic reactions'}
                  </div>
                </div>
              </div>
              
              {/* Patient Conditions for Injections */}
              <div className="medical-details-section" style={{ marginBottom: '1vw' }}>
                <div className="section-title" style={{ fontSize: '0.7vw', marginBottom: '0.5vw' }}>
                  <i className="fas fa-user-injured"></i>
                  <span>{data.translations?.ui_emergengyConditions || 'EMERGENCY/SEVERE CONDITIONS'}</span>
                </div>
                <div className="treatment-grid">
                  {Object.entries(discoveredInjuries).filter(([bodyPart, discoveredWound]) => {
                    if (!discoveredWound) return false;
                    // Show severe pain (8+) or any critical bleeding (7+) for emergency injections
                    return (discoveredWound.painLevel && discoveredWound.painLevel >= 8) || (discoveredWound.bleedingLevel && discoveredWound.bleedingLevel >= 7);
                  }).map(([bodyPart, discoveredWound]) => {
                    if (!discoveredWound) return null;
                    
                    const painLevel = discoveredWound.painLevel || 0;
                    const bleedingLevel = discoveredWound.bleedingLevel || 0;
                    
                    return (
                      <div 
                        key={bodyPart} 
                        className={`treatment-option ${selectedBodyPart === bodyPart ? 'selected' : ''}`}
                        onClick={() => setSelectedBodyPart(bodyPart)}
                        style={{
                          padding: '0.6vw',
                          background: selectedBodyPart === bodyPart ? 'rgba(226, 199, 146, 0.15)' : 'rgba(0, 0, 0, 0.2)',
                          border: `1px solid ${selectedBodyPart === bodyPart ? 'white' : 'rgba(226, 199, 146, 0.4)'}`,
                          borderRadius: '0.3vw',
                          cursor: 'pointer',
                          display: 'flex',
                          flexDirection: 'column',
                          alignItems: 'center',
                          textAlign: 'center',
                          transition: 'background 0.2s ease',
                          margin: '0.2vw'
                        }}
                      >
                        <span style={{ color: 'white', fontSize: '0.7vw' }}>
                          {getBodyPartName(bodyPart).toUpperCase()}
                        </span>
                        <span style={{ 
                          color: (painLevel >= 8 || bleedingLevel >= 7) ? '#e74c3c' : '#f39c12',
                          fontSize: '0.6vw'
                        }}>
                          {painLevel >= 8 && bleedingLevel >= 7 ? (data.translations?.ui_criticalEmergency || 'Critical Emergency') : 
                           painLevel >= 8 ? (data.translations?.ui_severePain || 'Severe Pain') : (data.translations?.ui_severeBleeding || 'Severe Bleeding')}
                        </span>
                      </div>
                    );
                  })}
                  {Object.entries(discoveredInjuries).filter(([bodyPart, discoveredWound]) => {
                    if (!discoveredWound) return false;
                    return (discoveredWound.painLevel && discoveredWound.painLevel >= 8) || (discoveredWound.bleedingLevel && discoveredWound.bleedingLevel >= 7);
                  }).length === 0 && (
                    <div style={{ color: 'rgba(255, 255, 255, 0.6)', fontSize: '0.6vw', fontStyle: 'italic', textAlign: 'center', padding: '1vw' }}>
                      {Object.keys(discoveredInjuries).length === 0 
                        ? (data.translations?.ui_noWoundsDiscovered || 'No wounds discovered yet. Perform body inspection to identify critical conditions.') 
                        : (data.translations?.ui_noEmergencyConditions || 'No emergency conditions found (requires severe pain 8+ or critical bleeding 7+).')}
                    </div>
                  )}
                </div>
              </div>

              {/* Available Injections */}
              <div className="medical-details-section" style={{ marginBottom: '1vw' }}>
                <div className="section-title" style={{ fontSize: '0.7vw', marginBottom: '0.5vw' }}>
                  <i className="fas fa-briefcase"></i>
                  <span>{data.translations?.ui_availableInjuctions || 'AVAILABLE INJECTIONS'}</span>
                </div>
                <div className="injection-selection-grid" style={{ display: 'flex', flexWrap: 'wrap', gap: '0.4vw' }}>
                  {injectionTypes.map((injection) => (
                    <div 
                      key={injection.id}
                      className={`injection-type ${selectedInjectionType === injection.id ? 'selected' : ''}`}
                      onClick={() => setSelectedInjectionType(injection.id)}
                      style={{
                        padding: '0.8vw',
                        height: 'auto',
                        background: selectedInjectionType === injection.id ? 'rgba(226, 199, 146, 0.15)' : 'rgba(0, 0, 0, 0.2)',
                        border: `1px solid ${selectedInjectionType === injection.id ? 'white' : 'rgba(226, 199, 146, 0.4)'}`,
                        borderRadius: '0.3vw',
                        cursor: 'pointer',
                        display: 'flex',
                        alignItems: 'center',
                        flex: '0 0 calc(50% - 0.2vw)',
                        boxSizing: 'border-box',
                        transition: 'background 0.2s ease'
                      }}
                    >
                      <div style={{ display: 'flex', flexDirection: 'column', alignItems: 'center', textAlign: 'center', width: '100%' }}>
                        <i className={`fas ${injection.icon}`} style={{ 
                          fontSize: '1.8vw', 
                          color: 'white', 
                          marginBottom: '0.3vw'
                        }}></i>
                        <div style={{ color: 'white', fontSize: '0.8vw', fontWeight: 'bold', marginBottom: '0.2vw' }}>{injection.name}</div>
                        <div style={{ color: 'rgba(226, 199, 146, 0.9)', fontSize: '0.65vw', lineHeight: '1.2' }}>{injection.desc}</div>
                      </div>
                    </div>
                  ))}
                </div>
              </div>


              {/* Inject Button */}
              {selectedInjectionType && selectedBodyPart && (
                <div style={{ textAlign: 'center', marginTop: '1vw' }}>
                  <button 
                    onClick={ui_giveInjection}
                    style={{
                      backgroundImage: 'url("./static/media/selection_box_bg_1d.db795b7cbe6db75cb337.png")',
                      backgroundSize: 'cover',
                      backgroundPosition: 'center',
                      color: 'white',
                      border: 'none',
                      padding: '0.8vw 2vw',
                      borderRadius: '0.3vw',
                      fontSize: '0.7vw',
                      cursor: 'pointer',
                      fontWeight: 'bold'
                    }}
                  >
                    <i className="fas fa-syringe" style={{ marginRight: '0.5vw' }}></i>
                    ADMINISTER INJECTION
                  </button>
                </div>
              )}
            </div>
          )}
        </div>
      </div>

      {/* Vitals Submenu - Bottom Center */}
      {showVitalsSubMenu && (
        <div className={`vitals-submenu ${vitalsAnimating ? 'submenu-slide-in' : ''}`} style={{
          position: 'fixed',
          bottom: '5vw',
          left: '50%',
          transform: 'translateX(-50%)',
          backgroundImage: 'url("./static/media/weathered_paper.c9db93c7dce51ddf09b9.png")',
          backgroundSize: '100% 100%',
          backgroundPosition: 'center',
          borderRadius: '0.5vw',
          padding: '1vw',
          zIndex: 1000,
          minWidth: '20vw',
        }}>
          <div className="submenu-title" style={{ 
            color: 'white', 
            fontSize: '0.8vw', 
            fontWeight: 'bold', 
            textAlign: 'center',
            marginBottom: '1vw',
          }}>
            <i className="fas fa-heartbeat" style={{ marginRight: '0.5vw' }}></i>
            {data.translations?.ui_vitalSignsChecking || 'VITAL SIGNS CHECK'}
          </div>
          
          {!ui_vitalsChecked ? (
            <div style={{ textAlign: 'center' }}>
              {/* Animated Heart - Always visible */}
              <style>
                {`
                  .heartbeat-animation {
                    animation: heartbeat-pulse ${checkingVitals ? Math.max(0.5, 2 - (vitalsProgress / 50)) : 1.2}s ease-in-out infinite;
                  }
                  @keyframes heartbeat-pulse {
                    0% { transform: scale(1); opacity: 1; }
                    50% { transform: scale(1.4); opacity: 0.8; }
                    100% { transform: scale(1); opacity: 1; }
                  }
                `}
              </style>
              <div className="heartbeat-animation" style={{ 
                fontSize: '3vw', 
                color: '#e74c3c', 
                marginBottom: '1vw',
                textAlign: 'center'
              }}>
                <i className="fas fa-heart"></i>
              </div>
              
              <div style={{ fontSize: '0.6vw', color: 'white', marginBottom: '1vw' }}>
                {checkingVitals ? (data.translations?.ui_listeningHeartbeat || 'Listening for heartbeat... Keep holding!') : (data.translations?.ui_holdToCheckVitals || 'Hold the button below for 3 seconds')}
              </div>
              
              <div style={{ display: 'flex', gap: '1vw', justifyContent: 'center' }}>
                <button 
                  onMouseDown={startVitalsCheck}
                  onMouseUp={stopVitalsCheck}
                  onMouseLeave={stopVitalsCheck}
                  style={{
                    backgroundImage: 'url("./static/media/selection_box_bg_1d.db795b7cbe6db75cb337.png")',
                    backgroundSize: 'cover',
                    backgroundPosition: 'center',
                    color: 'white',
                    border: 'none',
                    padding: '0.6vw 1.2vw',
                    borderRadius: '0.3vw',
                    fontSize: '0.6vw',
                    cursor: 'pointer',
                    position: 'relative',
                    overflow: 'hidden',
                    textShadow: '1px 1px 2px rgba(0,0,0,0.7)',
                    fontWeight: 'bold'
                  }}
                >
                  <i className="fas fa-hand-paper" style={{ marginRight: '0.5vw' }}></i>
                  {checkingVitals ? (data.translations?.ui_checking || 'CHECKING...') : (data.translations?.ui_holdToCheck || 'HOLD TO CHECK')}
                  {checkingVitals && (
                    <div style={{
                      position: 'absolute',
                      bottom: 0,
                      left: 0,
                      width: `${vitalsProgress}%`,
                      height: '100%',
                      background: 'rgba(39, 174, 96, 0.3)',
                      transition: 'width 0.1s ease'
                    }}></div>
                  )}
                </button>
                
                <button 
                  onClick={closeVitalsSubMenu}
                  style={{
                    backgroundImage: 'url("./static/media/selection_box_bg_1d.db795b7cbe6db75cb337.png")',
                    backgroundSize: 'cover',
                    backgroundPosition: 'center',
                    color: 'white',
                    border: 'none',
                    padding: '0.6vw 1.2vw',
                    borderRadius: '0.3vw',
                    fontSize: '0.6vw',
                    cursor: 'pointer',
                    textShadow: '1px 1px 2px rgba(0,0,0,0.7)',
                    fontWeight: 'bold'
                  }}
                >
                  {data.translations?.ui_cancel || 'CANCEL'}
                </button>
              </div>
            </div>
          ) : (
            <div style={{ display: 'flex', flexDirection: 'column', gap: '0.3vw', padding: '0 1vw' }}>
              <div style={{ display: 'flex', justifyContent: 'space-between', fontSize: '0.6vw', padding: '0 0.5vw' }}>
                <span style={{ color: 'white' }}>Heart Rate:</span>
                <span style={{ 
                  color: vitals.heartRate > 100 || vitals.heartRate < 60 ? '#e74c3c' : '#27ae60', 
                  fontWeight: 'bold', 
                  textShadow: '1px 1px 2px rgba(0,0,0,0.3)' 
                }}>{vitals.heartRate} BPM</span>
              </div>
              <div style={{ display: 'flex', justifyContent: 'space-between', fontSize: '0.6vw', padding: '0 0.5vw' }}>
                <span style={{ color: 'white' }}>Status:</span>
                <span style={{ color: vitals.statusColor, fontWeight: 'bold' }}>{vitals.status}</span>
              </div>
              <button 
                onClick={() => {closeVitalsSubMenu(); setVitalsChecked(false);}}
                style={{
                  backgroundImage: 'url("./static/media/selection_box_bg_1d.db795b7cbe6db75cb337.png")',
                  backgroundSize: 'cover',
                  backgroundPosition: 'center',
                  color: 'white',
                  border: 'none',
                  padding: '0.5vw',
                  borderRadius: '0.3vw',
                  fontSize: '0.6vw',
                  cursor: 'pointer',
                  marginTop: '0.5vw',
                  textShadow: '1px 1px 2px rgba(0,0,0,0.7)',
                  fontWeight: 'bold'
                }}
              >
                CLOSE
              </button>
            </div>
          )}
        </div>
      )}

      {/* Doctor's Bag Submenu - Bottom Center */}
      {showDoctorsBagSubMenu && (
        <div className={`doctors-bag-submenu ${ui_doctorsBagAnimating ? 'submenu-slide-in' : ''}`} style={{
          position: 'fixed',
          bottom: '5vw',
          left: '50%',
          transform: 'translateX(-50%)',
          backgroundImage: 'url("./static/media/weathered_paper.c9db93c7dce51ddf09b9.png")',
          backgroundSize: '100% 100%',
          backgroundPosition: 'center',
          borderRadius: '0.5vw',
          padding: '1vw',
          zIndex: 1000,
          minWidth: '25vw'
        }}>
          <div className="submenu-title" style={{ 
            color: 'white', 
            fontSize: '0.8vw', 
            fontWeight: 'bold', 
            textAlign: 'center',
            marginBottom: '1vw',
          }}>
            <i className="fas fa-briefcase-medical" style={{ marginRight: '0.5vw' }}></i>
            {data.translations?.ui_doctorsBag || 'DOCTORS BAG'}
          </div>
          
          <div className="medical-tools-grid" style={{ display: 'grid', gridTemplateColumns: 'repeat(2, 1fr)', gap: '0.5vw' }}>
            {[
              { name: 'Stethoscope', icon: 'fa-stethoscope', action: 'stethoscope', desc: 'Check heart and lung sounds' },
              { name: 'Thermometer', icon: 'fa-thermometer-half', action: 'thermometer', desc: 'Measure body temperature' },
              { name: 'Laudanum', icon: 'fa-prescription-bottle', action: 'laudanum', desc: 'Opium-based painkiller' },
              { name: 'Whiskey', icon: 'fa-wine-bottle', action: 'whiskey', desc: 'Antiseptic and anesthetic' },
              { name: 'Field Surgery Kit', icon: 'fa-first-aid', action: 'field-kit', desc: 'Emergency surgical tools' },
              { name: 'Smelling Salts', icon: 'fa-vial', action: 'smelling-salts', desc: 'Revive unconscious patients' }
            ].map((tool, index) => (
              <div
                key={index}
                className="medical-tool"
                onClick={() => {
                  // All tools now go through handleMedicalAction for inventory validation
                  handleMedicalAction('use-tool', tool.action);
                }}
                style={{
                  backgroundImage: 'url("./static/media/selection_box_bg_1d.db795b7cbe6db75cb337.png")',
                  backgroundSize: 'cover',
                  backgroundPosition: 'center',
                  padding: '0.6vw',
                  borderRadius: '0.3vw',
                  cursor: 'pointer',
                  border: 'none',
                  display: 'flex',
                  alignItems: 'center',
                  justifyContent: 'flex-start',
                  transition: 'transform 0.1s ease'
                }}
                onMouseEnter={(e) => e.currentTarget.style.transform = 'scale(1.02)'}
                onMouseLeave={(e) => e.currentTarget.style.transform = 'scale(1)'}
              >
                <div style={{
                  width: '2.5vw',
                  display: 'flex',
                  justifyContent: 'center',
                  alignItems: 'center',
                  marginRight: '0.5vw'
                }}>
                  <i className={`fas ${tool.icon}`} style={{ 
                    fontSize: '1.2vw', 
                    color: 'white'
                  }}></i>
                </div>
                <div>
                  <div style={{ color: 'white', fontSize: '0.6vw', fontWeight: 'bold', marginBottom: '0.1vw' }}>{tool.name}</div>
                  <div style={{ color: tool.desc.includes('painkiller') || tool.desc.includes('Opium') ? '#e74c3c' : tool.desc.includes('Check') || tool.desc.includes('Measure') ? '#27ae60' : '#f39c12', fontSize: '0.45vw' }}>{tool.desc}</div>
                </div>
              </div>
            ))}
          </div>
          
          <div style={{ textAlign: 'center', marginTop: '1vw' }}>
            <button 
              onClick={closeDoctorsBagSubMenu}
              style={{
                backgroundImage: 'url("./static/media/selection_box_bg_1d.db795b7cbe6db75cb337.png")',
                backgroundSize: 'cover',
                backgroundPosition: 'center',
                color: 'white',
                border: 'none',
                padding: '0.5vw 1vw',
                borderRadius: '0.3vw',
                fontSize: '0.6vw',
                cursor: 'pointer',
                textShadow: '1px 1px 2px rgba(0,0,0,0.7)',
                fontWeight: 'bold'
              }}
            >
              <i className="fas fa-times" style={{ marginRight: '0.5vw' }}></i>
              CLOSE BAG
            </button>
          </div>
        </div>
      )}

      {/* Thermometer Submenu - Bottom Center */}
      {showThermometerSubMenu && (
        <div className="thermometer-submenu" style={{
          position: 'fixed',
          bottom: '5vw',
          left: '50%',
          transform: 'translateX(-50%)',
          backgroundImage: 'url("./static/media/weathered_paper.c9db93c7dce51ddf09b9.png")',
          backgroundSize: '100% 100%',
          backgroundPosition: 'center',
          borderRadius: '0.5vw',
          padding: '1vw',
          zIndex: 1000,
          minWidth: '20vw'
        }}>
          <div className="submenu-title" style={{ 
            color: 'white', 
            fontSize: '0.8vw', 
            fontWeight: 'bold', 
            textAlign: 'center',
            marginBottom: '1vw',
          }}>
            <i className="fas fa-thermometer-half" style={{ marginRight: '0.5vw' }}></i>
            TEMPERATURE CHECK
          </div>
          
          {!temperatureChecked ? (
            <div style={{ textAlign: 'center' }}>
              {/* Thermometer with filling animation */}
              <div style={{ position: 'relative', marginBottom: '1vw', display: 'inline-block' }}>
                <style>
                  {`
                    .thermometer-container {
                      position: relative;
                      display: inline-block;
                    }
                    .thermometer-fill {
                      position: absolute;
                      bottom: 0.8vw;
                      left: 50%;
                      transform: translateX(-50%);
                      width: 0.2vw;
                      background: linear-gradient(to top, #e74c3c 0%, #f39c12 70%, #f1c40f 100%);
                      transition: height 0.1s ease;
                      z-index: -1;
                      border-radius: 0.1vw;
                    }
                  `}
                </style>
                <div className="thermometer-container">
                  <div 
                    className="thermometer-fill"
                    style={{ 
                      height: `${checkingTemperature ? temperatureProgress * 0.02 : 0}vw`
                    }}
                  ></div>
                  <i className="fas fa-thermometer-empty" style={{ 
                    fontSize: '4vw', 
                    color: '#8B4513',
                    position: 'relative',
                    zIndex: 1
                  }}></i>
                </div>
              </div>
              
              <div style={{ fontSize: '0.6vw', color: 'white', marginBottom: '1vw' }}>
                {checkingTemperature ? (data.translations?.ui_readingTemperature || 'Reading temperature... Keep holding!') : (data.translations?.ui_holdToCheckTemperature || 'Hold the button below for 3 seconds')}
              </div>
              
              <div style={{ display: 'flex', gap: '1vw', justifyContent: 'center' }}>
                <button 
                  onMouseDown={startTemperatureCheck}
                  onMouseUp={stopTemperatureCheck}
                  onMouseLeave={stopTemperatureCheck}
                  style={{
                    backgroundImage: 'url("./static/media/selection_box_bg_1d.db795b7cbe6db75cb337.png")',
                    backgroundSize: 'cover',
                    backgroundPosition: 'center',
                    color: 'white',
                    border: 'none',
                    padding: '0.6vw 1.2vw',
                    borderRadius: '0.3vw',
                    fontSize: '0.6vw',
                    cursor: 'pointer',
                    textShadow: '1px 1px 2px rgba(0,0,0,0.7)',
                    fontWeight: 'bold'
                  }}
                >
                  <i className="fas fa-thermometer-half" style={{ marginRight: '0.5vw' }}></i>
                  {checkingTemperature ? (data.translations?.ui_reading || 'READING...') : (data.translations?.ui_holdToCheck || 'HOLD TO CHECK')}
                </button>
                
                <button 
                  onClick={() => setShowThermometerSubMenu(false)}
                  style={{
                    backgroundImage: 'url("./static/media/selection_box_bg_1d.db795b7cbe6db75cb337.png")',
                    backgroundSize: 'cover',
                    backgroundPosition: 'center',
                    color: 'white',
                    border: 'none',
                    padding: '0.6vw 1.2vw',
                    borderRadius: '0.3vw',
                    fontSize: '0.6vw',
                    cursor: 'pointer',
                    textShadow: '1px 1px 2px rgba(0,0,0,0.7)',
                    fontWeight: 'bold'
                  }}
                >
                  {data.translations?.ui_cancel || 'CANCEL'}
                </button>
              </div>
            </div>
          ) : (
            <div style={{ textAlign: 'center' }}>
              <div style={{ fontSize: '1.5vw', color: '#8B4513', marginBottom: '1vw' }}>
                {calculateTemperature()}°F
              </div>
              <div style={{ fontSize: '0.6vw', color: '#8B4513', marginBottom: '1vw' }}>
                {calculateTemperature() > 100.4 ? (data.translations?.ui_feverDetected || 'Fever detected') : calculateTemperature() < 97 ? (data.translations?.ui_hypothermiaRisk || 'Hypothermia risk') : (data.translations?.ui_normalTemperature || 'Normal temperature')}
              </div>
              <button 
                onClick={() => {
                  setShowThermometerSubMenu(false); 
                  setTemperatureChecked(false);
                  showNotification(`${data.translations?.ui_patientTemperature || 'Patient temperature'}: ${calculateTemperature()}°F`, 'fa-thermometer-half');
                }}
                style={{
                  backgroundImage: 'url("./static/media/selection_box_bg_1d.db795b7cbe6db75cb337.png")',
                  backgroundSize: 'cover',
                  backgroundPosition: 'center',
                  color: 'white',
                  border: 'none',
                  padding: '0.5vw',
                  borderRadius: '0.3vw',
                  fontSize: '0.6vw',
                  cursor: 'pointer',
                  textShadow: '1px 1px 2px rgba(0,0,0,0.7)',
                  fontWeight: 'bold'
                }}
              >
                CLOSE
              </button>
            </div>
          )}
        </div>
      )}

      {/* Notification System */}
      {notification && (
        <div className="notification notification-slide-in" style={{
          position: 'fixed',
          top: '2vw',
          left: '50%',
          transform: 'translateX(-50%)',
          backgroundImage: 'url("./static/media/weathered_paper.c9db93c7dce51ddf09b9.png")',
          backgroundSize: '100% 100%',
          backgroundPosition: 'center',
          borderRadius: '0.3vw',
          padding: '1.2vw 0.8vw',
          color: 'white',
          fontSize: '0.7vw',
          zIndex: 1001,
          textShadow: '1px 1px 2px rgba(0,0,0,0.7)',
          fontWeight: 'bold',
          width: '10vw',
          textAlign: 'center',
          display: 'flex',
          flexDirection: 'column',
          alignItems: 'center',
          gap: '0.5vw'
        }}>
          <style>
            {`
              .notification-icon-shake {
                animation: notification-shake 0.5s ease-in-out infinite;
              }
              @keyframes notification-shake {
                0%, 100% { transform: translateX(0); }
                25% { transform: translateX(-2px); }
                75% { transform: translateX(2px); }
              }
              .notification-slide-in {
                animation: notification-slide-in 0.5s ease-out forwards, notification-slide-out 0.5s ease-in 4s forwards;
              }
              @keyframes notification-slide-in {
                0% { 
                  transform: translateX(-50%) translateY(-100%);
                  opacity: 0;
                }
                100% { 
                  transform: translateX(-50%) translateY(0);
                  opacity: 1;
                }
              }
              @keyframes notification-slide-out {
                0% { 
                  transform: translateX(-50%) translateY(0);
                  opacity: 1;
                }
                100% { 
                  transform: translateX(-50%) translateY(-100%);
                  opacity: 0;
                }
              }
            `}
          </style>
          <i className={`fas ${notification.icon} notification-icon-shake`} style={{ fontSize: '1.5vw', color: '#27ae60' }}></i>
          <div>{notification.message}</div>
        </div>
      )}


    </div>
  );
};

export default InspectionPanel;