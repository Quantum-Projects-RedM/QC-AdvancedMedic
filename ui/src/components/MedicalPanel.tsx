import React, { useState, useEffect } from 'react';
import '../assets/css/medpanel.css';
// @ts-ignore
import weatheredPaper from '../assets/imgs/weathered_paper.png';
// @ts-ignore
import selectionBoxBg from '../assets/imgs/selection_box_bg_1d.png';

interface MedicalPanelProps {
  wounds: {
    [key: string]: {
      health?: number; // Legacy support
      painLevel?: number;
      bleedingLevel?: number;
    };
  };
  treatments: any[];
  infections?: {
    [key: string]: {
      stage: number;
      symptom: string;
    };
  };
  bodyPartHealth?: {
    [key: string]: {
      current: number;
      max: number;
      percentage: number;
    };
  };
  injuryStates?: {
    [key: number]: {
      pain: string;
      bleeding: string;
      urgency: string;
      treatment: string;
    };
  };
  infectionStages?: {
    [key: number]: { 
      name: string;
      color: string;
    };
  };
  bodyParts?: {
    [key: string]: {
      label: string;
      maxHealth: number;
      limp: boolean;
    };
  };
  uiColors?: {
    [key: string]: string;
  };
  inventory?: {
    [key: string]: number; // item name -> quantity
  };
  bandageTypes?: {
    [key: string]: {
      itemName: string;
      label: string;
      decayRate: number;
    };
  };
  isSelfExamination?: boolean;
  translations?: { [key: string]: string };
  onClose: () => void;
}

const MedicalPanel: React.FC<MedicalPanelProps> = ({ wounds, treatments, infections, bodyPartHealth, injuryStates, infectionStages, bodyParts, uiColors, inventory, bandageTypes, isSelfExamination, translations, onClose }) => {
  const [showBandagePanel, setShowBandagePanel] = useState(false);
  const [showTourniquetPanel, setShowTourniquetPanel] = useState(false);
  const [showTreatmentsPanel, setShowTreatmentsPanel] = useState(false);
  const [selectedBodyPart, setSelectedBodyPart] = useState<string>('');
  const [selectedTourniquetBodyPart, setSelectedTourniquetBodyPart] = useState<string>('');

  // New states for real-time inventory checking
  const [loadingInventory, setLoadingInventory] = useState(false);
  const [currentInventory, setCurrentInventory] = useState<any>(null);
  const [currentWounds, setCurrentWounds] = useState<any>(null);

  // ESC key handler to close panel
  useEffect(() => {
    const handleKeyDown = (event: KeyboardEvent) => {
      if (event.key === 'Escape') {
        onClose();
      }
    };

    window.addEventListener('keydown', handleKeyDown);
    return () => window.removeEventListener('keydown', handleKeyDown);
  }, [onClose]);

  const mapBodyPartName = (bodyPart: string) => {
    // Map component body part names to Config.BodyParts keys
    const bodyPartMap: { [key: string]: string } = {
      'head': 'HEAD',
      'neck': 'NECK', 
      'spine': 'SPINE',
      'upper': 'UPPER_BODY',
      'lower': 'LOWER_BODY',
      'larm': 'LARM',
      'rarm': 'RARM',
      'lhand': 'LHAND',
      'rhand': 'RHAND',
      'lleg': 'LLEG',
      'rleg': 'RLEG',
      'lfoot': 'LFOOT',
      'rfoot': 'RFOOT',
      'blood': 'BLOOD' // Special case for blood level
    };
    return bodyPartMap[bodyPart] || bodyPart.toUpperCase();
  };

  const getHealthPercentage = (bodyPart: string) => {
    const configBodyPart = mapBodyPartName(bodyPart);
    
    // Use new bodyPartHealth system if available, fallback to legacy wound.health
    if (bodyPartHealth && bodyPartHealth[configBodyPart]) {
      return bodyPartHealth[configBodyPart].percentage;
    }
    const wound = wounds[configBodyPart] || wounds[bodyPart];
    return wound ? (wound.health || 100) : 100;
  };
  
  const getHealthColor = (percentage: number, bodyPart: string) => {
    const configBodyPart = mapBodyPartName(bodyPart);
    const infection = getInfectionInfo(configBodyPart);
    const hasBandage = getHasBandage(configBodyPart);
    const hasTourniquet = getHasTourniquet(configBodyPart);
    
    // Color hierarchy: bandaged > tourniquet > infected > health-based
    if (hasBandage) return uiColors?.bandaged || '#3498db';        // Blue - has active bandage
    if (hasTourniquet) return uiColors?.tourniquet || '#f1c40f';   // Yellow - has active tourniquet  
    if (infection.stage > 0) return uiColors?.infected || '#9C27B0'; // Purple - has active infection
    
    // Health-based colors (only show if no treatments/infections)
    if (percentage >= 70) return uiColors?.normal || '#27ae60';    // Green - 70%+ health (normal)
    if (percentage >= 30) return uiColors?.medium || '#f39c12';    // Orange - 30-70% health (medium)
    return uiColors?.low || '#e74c3c';                            // Red - <30% health (low)
  };

  const getHasBandage = (bodyPart: string) => {
    // Check treatments array for bandages on this body part
    return treatments.some(treatment => 
      treatment.bodyPart === bodyPart && treatment.type === 'bandage'
    );
  };

  const getHasTourniquet = (bodyPart: string) => {
    // Check treatments array for tourniquets on this body part
    return treatments.some(treatment => 
      treatment.bodyPart === bodyPart && treatment.type === 'tourniquet'
    );
  };

  const getHealthText = (percentage: number) => {
    if (percentage >= 80) return 'Healthy';
    if (percentage >= 60) return 'Minor Injury';
    if (percentage >= 40) return 'Moderate Injury';
    if (percentage >= 20) return 'Serious Injury';
    return 'Critical';
  };

  const getInfectionInfo = (bodyPart: string) => {
    // Use real infection data if provided, otherwise return no infection
    if (infections && infections[bodyPart]) {
      return infections[bodyPart];
    }
    return { stage: 0, symptom: null };
  };

  // Get immersive pain description from config
  const getPainThought = (bodyPart: string, painLevel: number) => {
    if (!painLevel || painLevel === 0) return null;
    
    const bodyPartName = getBodyPartDisplayName(bodyPart);
    
    if (injuryStates && injuryStates[painLevel]) {
      return `My ${bodyPartName.toLowerCase()} ${injuryStates[painLevel].pain.toLowerCase()}`;
    }
    return `My ${bodyPartName.toLowerCase()} is in pain`;
  };

  // Get immersive bleeding description from config  
  const getBleedingThought = (bodyPart: string, bleedingLevel: number) => {
    if (!bleedingLevel || bleedingLevel === 0) return null;
    
    const bodyPartName = getBodyPartDisplayName(bodyPart);
    
    if (injuryStates && injuryStates[bleedingLevel]) {
      return `My ${bodyPartName.toLowerCase()} ${injuryStates[bleedingLevel].bleeding.toLowerCase()}`;
    }
    return `My ${bodyPartName.toLowerCase()} is bleeding`;
  };

  // Get body part display name
  const getBodyPartDisplayName = (bodyPart: string) => {
    const names: { [key: string]: string } = {
      'HEAD': 'head',
      'NECK': 'neck',
      'SPINE': 'spine', 
      'UPPER_BODY': 'chest',
      'LOWER_BODY': 'stomach',
      'LARM': 'left arm',
      'RARM': 'right arm',
      'LHAND': 'left hand',
      'RHAND': 'right hand',
      'LLEG': 'left leg',
      'RLEG': 'right leg',
      'LFOOT': 'left foot',
      'RFOOT': 'right foot'
    };
    return names[bodyPart] || bodyPart.toLowerCase();
  };

  // Check if infection is severe enough to notice
  const isSevereInfection = (stage: number) => {
    return stage >= 3; // Only stage 3+ infections are noticeable
  };

  const getPainDescription = (painLevel: number) => {
    if (injuryStates && injuryStates[painLevel]) {
      return injuryStates[painLevel].pain;
    }
    return `Pain level ${painLevel}`;
  };

  const getBleedingDescription = (bleedingLevel: number) => {
    if (injuryStates && injuryStates[bleedingLevel]) {
      return injuryStates[bleedingLevel].bleeding;
    }
    return `Bleeding level ${bleedingLevel}`;
  };

  const getInfectionStageInfo = (stage: number) => {
    // Use config infection stages if provided, otherwise fallback to defaults
    if (infectionStages && infectionStages[stage]) {
      return infectionStages[stage];
    }
    
    // Fallback defaults
    const defaultStages: { [key: number]: { name: string; color: string } } = {
      0: { name: "Healthy", color: "#00ff00" },
      1: { name: "Early Infection", color: "#ffff00" },
      2: { name: "Moderate Infection", color: "#ff8000" },
      3: { name: "Serious Infection", color: "#ff4000" },
      4: { name: "Severe Infection", color: "#ff0000" }
    };
    return defaultStages[stage] || defaultStages[0];
  };

  const BodyPartBar: React.FC<{ bodyPart: string; label: string; imageName: string }> = ({ bodyPart, label, imageName }) => {
    const configBodyPart = mapBodyPartName(bodyPart);
    const health = getHealthPercentage(bodyPart);
    const color = getHealthColor(health, bodyPart);
    const text = getHealthText(health);
    const infection = getInfectionInfo(configBodyPart);
    const infectionStage = getInfectionStageInfo(infection.stage);
    const hasBandage = getHasBandage(configBodyPart);
    const hasTourniquet = getHasTourniquet(configBodyPart);
    
    // Check if this body part has any issues that warrant a tooltip
    const wound = wounds[configBodyPart] || wounds[bodyPart];
    const painLevel = wound?.painLevel || 0;
    const bleedingLevel = wound?.bleedingLevel || 0;
    const hasWoundIssues = painLevel > 0 || bleedingLevel > 0;
    const hasVisibleInfection = isSevereInfection(infection.stage) && !hasBandage;
    const hasAnyStatus = hasVisibleInfection || hasBandage || hasTourniquet || hasWoundIssues;
    

    // Determine animation class based on bandage and wound status
    const getAnimationClass = () => {
      if (!hasWoundIssues) return ''; // No animation if no wounds
      if (hasBandage) return 'bandaged-body-part'; // Gentle pulse if bandaged
      return 'wounded-body-part'; // Violent shake if wounded and unbandaged
    };

    return (
      <div className={`medic-${bodyPart.toLowerCase()}`}>
        <div className={`medic-${bodyPart.toLowerCase()}-first ${getAnimationClass()}`} style={{ position: 'relative' }}>
          <div className="body-part-icon"></div>
          <div className="body-part-label">{label}</div>
          
          {/* Status tooltip - only show when status exists and on hover */}
          {hasAnyStatus && (
          <div 
            className="infection-tooltip" 
            style={{ 
              backgroundImage: `url(${weatheredPaper})`,
              backgroundSize: '100% 100%',
              backgroundRepeat: 'no-repeat',
              backgroundPosition: 'center'
            }}
          >
            <div className="status-header" style={{ color: 'white', fontWeight: 'bold', marginBottom: '8px' }}>
              Status
            </div>
            
            {hasBandage && (
              <div className="status-item" style={{ color: '#3498db', marginBottom: '6px', fontStyle: 'italic' }}>
                "The bandage feels secure and is helping the healing."
              </div>
            )}
            
            {hasTourniquet && (
              <div className="status-item" style={{ color: '#f1c40f', marginBottom: '6px', fontStyle: 'italic' }}>
                "The tourniquet is stopping the bleeding but feels tight."
              </div>
            )}
            
            {hasVisibleInfection && (
              <div className="status-item" style={{ color: infectionStage.color, marginBottom: '6px', fontStyle: 'italic' }}>
                "{infection.symptom || 'Something doesn\'t feel right here...'}"
              </div>
            )}
            
            {getPainThought(configBodyPart, painLevel) && (
              <div className="status-item" style={{ color: '#ff6b6b', marginBottom: '6px', fontStyle: 'italic' }}>
                "{getPainThought(configBodyPart, painLevel)}"
              </div>
            )}
            
            {getBleedingThought(configBodyPart, bleedingLevel) && (
              <div className="status-item" style={{ color: '#e74c3c', marginBottom: '6px', fontStyle: 'italic' }}>
                "{getBleedingThought(configBodyPart, bleedingLevel)}"
              </div>
            )}
            
            {!hasAnyStatus && (
              <div className="status-item" style={{ color: '#27ae60', marginBottom: '6px', fontStyle: 'italic' }}>
                "This feels fine."
              </div>
            )}
          </div>
          )}
        </div>
        <div className={`medic-${bodyPart.toLowerCase()}-dd`}>
          <div className={`medic-${bodyPart.toLowerCase()}-dd-label`}>
            {label}: <span style={{ fontSize: '1.3vh', color: '#fff', marginLeft: '7px' }}>{text}</span>
          </div>
          <div className={`medic-${bodyPart.toLowerCase()}-dd-full`}>
            <div 
              className={`medic-${bodyPart.toLowerCase()}-dd-bar`}
              style={{ 
                width: `${health}%`,
                backgroundColor: color,
                transition: 'all 0.3s ease'
              }}
            ></div>
          </div>
        </div>
      </div>
    );
  };

  // Get wounds that can be bandaged (bleeding level under 6 AND not already bandaged)
  const getBandageableWounds = () => {
    const bandageableWounds: { [key: string]: any } = {};
    
    Object.entries(wounds).forEach(([bodyPart, wound]) => {
      // Check if this body part has a wound that needs bandaging AND is not already bandaged
      if (wound && typeof wound === 'object' && wound.bleedingLevel && wound.bleedingLevel < 6) {
        const hasBandage = getHasBandage(bodyPart);
        if (!hasBandage) { // Only include if NOT already bandaged
          bandageableWounds[bodyPart] = wound;
        }
      }
    });
    
    return bandageableWounds;
  };

  // Get available bandages from player inventory
  const getAvailableBandages = () => {
    if (!inventory || !bandageTypes) return [];
    
    return Object.values(bandageTypes).filter(bandage => {
      const quantity = inventory[bandage.itemName] || 0;
      return quantity > 0;
    }).map(bandage => ({
      ...bandage,
      quantity: inventory[bandage.itemName]
    }));
  };

  // Get wounds that need tourniquets (bleeding level 6+ AND not already tourniqueted)
  const getTourniquetableWounds = () => {
    const tourniquetableWounds: { [key: string]: any } = {};
    
    Object.entries(wounds).forEach(([bodyPart, wound]) => {
      // Check if this body part has severe bleeding (6+) AND is not already tourniqueted
      if (wound && typeof wound === 'object' && wound.bleedingLevel && wound.bleedingLevel >= 6) {
        const hasTourniquet = getHasTourniquet(bodyPart);
        if (!hasTourniquet) { // Only include if NOT already tourniqueted
          tourniquetableWounds[bodyPart] = wound;
        }
      }
    });
    
    return tourniquetableWounds;
  };

  // Get available tourniquets from player inventory (similar to bandages)
  const getAvailableTourniquets = () => {
    if (!inventory) return [];
    
    // Define tourniquet types (you may want to move this to config)
    const tourniquetTypes = {
      'tourniquet_basic': { itemName: 'tourniquet_basic', label: 'Basic Tourniquet' },
      'tourniquet_advanced': { itemName: 'tourniquet_advanced', label: 'Advanced Tourniquet' }
    };
    
    return Object.values(tourniquetTypes).filter(tourniquet => {
      const quantity = inventory[tourniquet.itemName] || 0;
      return quantity > 0;
    }).map(tourniquet => ({
      ...tourniquet,
      quantity: inventory[tourniquet.itemName]
    }));
  };

  const handleBandageClick = async () => {
    setShowBandagePanel(true);
    setShowTourniquetPanel(false);
    setShowTreatmentsPanel(false);
    setLoadingInventory(true);
    setCurrentInventory(null);
    setCurrentWounds(null);

    try {
      const response = await fetch(`https://${(window as any).GetParentResourceName?.() || 'qc-advancedmedic'}/get-current-inventory`, {
        method: 'POST',
        headers: { 'Content-Type': 'application/json' },
        body: JSON.stringify({})
      });

      const data = await response.json();
      setCurrentInventory(data.inventory);
      setCurrentWounds(data.wounds);
    } catch (error) {
      console.error('Failed to get inventory:', error);
      // Set empty data on error
      setCurrentInventory({ bandages: [], tourniquets: [], medicines: [], injections: [] });
      setCurrentWounds({});
    } finally {
      setLoadingInventory(false);
    }
  };

  const handleTourniquetClick = async () => {
    setShowTourniquetPanel(true);
    setShowBandagePanel(false);
    setShowTreatmentsPanel(false);
    setLoadingInventory(true);
    setCurrentInventory(null);
    setCurrentWounds(null);

    try {
      const response = await fetch(`https://${(window as any).GetParentResourceName?.() || 'qc-advancedmedic'}/get-current-inventory`, {
        method: 'POST',
        headers: { 'Content-Type': 'application/json' },
        body: JSON.stringify({})
      });

      const data = await response.json();
      setCurrentInventory(data.inventory);
      setCurrentWounds(data.wounds);
    } catch (error) {
      console.error('Failed to get inventory:', error);
      // Set empty data on error
      setCurrentInventory({ bandages: [], tourniquets: [], medicines: [], injections: [] });
      setCurrentWounds({});
    } finally {
      setLoadingInventory(false);
    }
  };

  const handleTreatmentsClick = () => {
    setShowTreatmentsPanel(true);
    setShowBandagePanel(false);
    setShowTourniquetPanel(false);
  };

  const closePanels = () => {
    setShowBandagePanel(false);
    setShowTourniquetPanel(false);
    setShowTreatmentsPanel(false);
    setSelectedBodyPart('');
    setSelectedTourniquetBodyPart('');
    setLoadingInventory(false);
    setCurrentInventory(null);
    setCurrentWounds(null);
  };

  return (
    <>
      {/* Custom CSS to fix positioning conflicts */}
      <style>
        {`
          /* Loading spinner animation */
          @keyframes spin {
            0% { transform: rotate(0deg); }
            100% { transform: rotate(360deg); }
          }

          /* Position legs to avoid hand overlap and mirror properly */
          .medic-details {
            position: relative !important;
          }
          
          .medic-lleg {
            position: absolute !important;
            top: 22vw !important;
            left: 0vw !important;
            margin-top: 0 !important;
          }
          
          .medic-rleg {
            position: absolute !important;
            top: 22vw !important;
            left: 0vw !important;
            margin-top: 0 !important;
          }
          
          .medic-lfoot {
            position: absolute !important;
            top: 25vw !important;
            left: 0vw !important;
            margin-top: 0 !important;
          }
          
          .medic-rfoot {
            position: absolute !important;
            top: 25vw !important;
            left: 0vw !important;
            margin-top: 0 !important;
          }
          
          /* Keep hands at original position */
          .medic-lhand {
            margin-top: 0.8vw !important;
          }
          
          .medic-rhand {
            margin-top: 0.8vw !important;
          }
          
          /* Move lower body down to proper position */
          .medic-lower {
            margin-top: 18vw !important;
          }
          
          /* Move action buttons right and down */
          .medic-actions-right {
            margin-left: 35vw !important;
            margin-top: -40vw !important;
          }
          
          /* Fix only the exit animation for tooltips - prevent width animation */
          .action-tooltip {
            transition: opacity 0.3s ease, transform 0.3s ease !important;
            white-space: nowrap !important;
          }
          
          /* Status tooltip styling */
          .infection-tooltip {
            position: absolute !important;
            top: 50% !important;
            left: 110% !important;
            transform: translateY(-50%) translateX(-10px) !important;
            border: none !important;
            border-radius: 8px !important;
            padding: 20px 24px !important;
            width: 320px !important;
            height: auto !important;
            min-height: 120px !important;
            z-index: 2000 !important;
            opacity: 0 !important;
            transition: opacity 0.3s ease, transform 0.3s ease !important;
            pointer-events: none !important;
            box-shadow: none !important;
            display: flex !important;
            flex-direction: column !important;
            justify-content: flex-start !important;
          }
          
          /* Hide body part icons completely from tooltip area */
          .infection-tooltip .body-part-icon {
            display: none !important;
          }
          
          /* Prevent any inherited background images in tooltip */
          .infection-tooltip * {
            background-image: none !important;
          }
          
          .infection-stage {
            font-family: "RDR Lino Regular" !important;
            font-size: 1.4vh !important;
            font-weight: bold !important;
            margin-bottom: 4px !important;
            text-shadow: 0px 0.2083vw 1.4583vw rgba(231, 175, 19, 0.55) !important;
          }
          
          .infection-symptom {
            font-family: "RDR Lino Regular" !important;
            font-size: 1.2vh !important;
            color: #e2c792 !important;
            line-height: 1.3 !important;
            text-shadow: 0px 0.2083vw 1.4583vw rgba(231, 175, 19, 0.55) !important;
          }
          
          .medic-head-first:hover .infection-tooltip,
          .medic-spine-first:hover .infection-tooltip,
          .medic-upper-first:hover .infection-tooltip,
          .medic-larm-first:hover .infection-tooltip,
          .medic-rarm-first:hover .infection-tooltip,
          .medic-lhand-first:hover .infection-tooltip,
          .medic-rhand-first:hover .infection-tooltip,
          .medic-lleg-first:hover .infection-tooltip,
          .medic-rleg-first:hover .infection-tooltip,
          .medic-lfoot-first:hover .infection-tooltip,
          .medic-rfoot-first:hover .infection-tooltip,
          .medic-lower-first:hover .infection-tooltip {
            opacity: 1 !important;
            transform: translateY(-50%) translateX(0) !important;
          }
          
          /* Additional styling for status items */
          .status-header {
            font-family: "RDR Lino Regular" !important;
            font-size: 1.8vh !important;
            color: white !important;
            text-shadow: 1px 1px 2px rgba(0, 0, 0, 0.3) !important;
            margin-bottom: 6px !important;
            text-align: center !important;
          }
          
          .status-item {
            font-family: "RDR Lino Regular" !important;
            font-size: 1.4vh !important;
            text-shadow: 1px 1px 2px rgba(0, 0, 0, 0.3) !important;
            margin-bottom: 6px !important;
            line-height: 1.4 !important;
          }
          
          /* Bandage panel animations */
          @keyframes slideInFromRight {
            from {
              transform: translateX(100%);
              opacity: 0;
            }
            to {
              transform: translateX(0);
              opacity: 1;
            }
          }
          
          @keyframes buttonSlideOut {
            from {
              transform: translateX(0);
              opacity: 1;
            }
            to {
              transform: translateX(200%);
              opacity: 0;
            }
          }
          
          /* Button animation when bandage panel is open */
          .medic-actions-right .action-button.bandage-active {
            animation: buttonSlideOut 0.3s ease-out forwards;
          }
          
          /* Button animation when treatments panel is open */
          .medic-actions-right .action-button.treatments-active {
            animation: buttonSlideOut 0.3s ease-out forwards;
          }
          
          /* Button animation when tourniquet panel is open */
          .medic-actions-right .action-button.tourniquet-active {
            animation: buttonSlideOut 0.3s ease-out forwards;
          }
          
          /* Treatment panel slide animation */
          .treatments-selection-panel {
            animation: slideInFromRight 0.3s ease-out !important;
          }
          
          /* Hover effects for panel items */
          .body-part-option:hover {
            transform: scale(0.98);
            filter: brightness(1.1);
          }
          
          .bandage-option:hover {
            transform: scale(0.97);
            filter: brightness(1.1);
          }
          
          .treatment-option:hover {
            transform: scale(0.98);
            filter: brightness(1.1);
          }
          
          .treatment-option button:hover {
            transform: scale(0.95);
            filter: brightness(1.2);
          }
          
          /* Pain shake animation for wounded unbandaged body parts */
          @keyframes painShake {
            0%, 60% { transform: rotate(0deg) scale(1); }
            61% { transform: rotate(-5deg) scale(1.08); }
            63% { transform: rotate(6deg) scale(1.08); }
            65% { transform: rotate(-6deg) scale(1.08); }
            67% { transform: rotate(4deg) scale(1.08); }
            69% { transform: rotate(-4deg) scale(1.06); }
            71% { transform: rotate(5deg) scale(1.06); }
            73% { transform: rotate(-5deg) scale(1.06); }
            75% { transform: rotate(3deg) scale(1.04); }
            77% { transform: rotate(-3deg) scale(1.04); }
            79% { transform: rotate(2deg) scale(1.02); }
            81% { transform: rotate(-2deg) scale(1.02); }
            83% { transform: rotate(1deg) scale(1.01); }
            85%, 100% { transform: rotate(0deg) scale(1); }
          }
          
          /* Gentle pulse animation for bandaged body parts */
          @keyframes healingPulse {
            0%, 85% { transform: scale(1); opacity: 1; }
            90% { transform: scale(1.03); opacity: 0.9; }
            95% { transform: scale(1.05); opacity: 0.8; }
            100% { transform: scale(1); opacity: 1; }
          }
          
          .wounded-body-part {
            animation: painShake 5s ease-in-out infinite;
          }
          
          .bandaged-body-part {
            animation: healingPulse 5s ease-in-out infinite;
          }
          
          .wounded-body-part:hover,
          .bandaged-body-part:hover {
            animation-play-state: paused;
          }
          
          /* Stagger animation delays for wounded body parts */
          .medic-head-first.wounded-body-part { animation-delay: 0.5s; }
          .medic-upper-first.wounded-body-part { animation-delay: 1.0s; }
          .medic-larm-first.wounded-body-part { animation-delay: 1.5s; }
          .medic-rarm-first.wounded-body-part { animation-delay: 2.0s; }
          .medic-lower-first.wounded-body-part { animation-delay: 2.5s; }
          .medic-lleg-first.wounded-body-part { animation-delay: 3.0s; }
          .medic-rleg-first.wounded-body-part { animation-delay: 3.5s; }
          
          /* Stagger animation delays for bandaged body parts */
          .medic-head-first.bandaged-body-part { animation-delay: 0.8s; }
          .medic-upper-first.bandaged-body-part { animation-delay: 1.3s; }
          .medic-larm-first.bandaged-body-part { animation-delay: 1.8s; }
          .medic-rarm-first.bandaged-body-part { animation-delay: 2.3s; }
          .medic-lower-first.bandaged-body-part { animation-delay: 2.8s; }
          .medic-lleg-first.bandaged-body-part { animation-delay: 3.3s; }
          .medic-rleg-first.bandaged-body-part { animation-delay: 3.8s; }
          
          /* Back button styling and hover effect */
          .back-to-body-parts-btn {
            pointer-events: all !important;
            user-select: none !important;
            z-index: 1001 !important;
            position: relative !important;
          }
          
          .back-to-body-parts-btn:hover {
            transform: scale(0.95) !important;
            filter: brightness(1.2) !important;
          }
          
          /* Ensure content area doesn't block pointer events */
          .treatments-detail-content {
            pointer-events: none;
          }
          
          .treatments-detail-content > * {
            pointer-events: auto;
          }
        `}
      </style>
      <div className="medic-system">
        <div className="medic-close" onClick={onClose} style={{ position: 'absolute', top: '20px', right: '30px', zIndex: 10, fontSize: '32px', color: '#fff', cursor: 'pointer' }}>
          &times;
        </div>
        <div className="medic-big">
          <div className="medic-label">Medical <span>Panel</span></div>
          <div className="medic-details">
            
            <BodyPartBar bodyPart="head" label="HEAD" imageName="head" />
            <BodyPartBar bodyPart="spine" label="SPINE" imageName="spine" />
            <BodyPartBar bodyPart="upper" label="UPPER BODY" imageName="upper" />
            
            {/* Front-facing view - Labels mirrored but data stays with CSS positioning */}
            <BodyPartBar bodyPart="larm" label="RIGHT ARM" imageName="larm" />
            
            <BodyPartBar bodyPart="lhand" label="RIGHT HAND" imageName="lhand" />
            
            <BodyPartBar bodyPart="rarm" label="LEFT ARM" imageName="rarm" />
            
            <BodyPartBar bodyPart="rhand" label="LEFT HAND" imageName="rhand" />
            
            {/* Legs positioned properly - mirrored for front-facing view */}
            <BodyPartBar bodyPart="lleg" label="RIGHT LEG" imageName="lleg" />
            
            <BodyPartBar bodyPart="rleg" label="LEFT LEG" imageName="rleg" />
            
            {/* Feet positioned below their respective legs */}
            <BodyPartBar bodyPart="lfoot" label="RIGHT FOOT" imageName="lfoot" />
            <BodyPartBar bodyPart="rfoot" label="LEFT FOOT" imageName="rfoot" />
            
            <BodyPartBar bodyPart="lower" label="LOWER BODY" imageName="lower" />
            
            <div className="medic-blood">
              <div className="medic-blood-first"><div></div></div>
              <div className="medic-blood-dd">
                <div className="medic-blood-dd-label">Blood Level: <span style={{ fontSize: '1.3vh', color: '#fff', marginLeft: '7px' }}>{getHealthText(getHealthPercentage('blood'))}</span></div>
                <div className="medic-blood-dd-full">
                  <div className="medic-blood-dd-bar" style={{ width: `${getHealthPercentage('blood')}%`, backgroundColor: getHealthColor(getHealthPercentage('blood'), 'blood') }}></div>
                </div>
              </div>
            </div>
            
          </div>
          
          {/* Action Buttons */}
          <div className="medic-actions-right">
            <div className={`action-button ${showBandagePanel ? 'bandage-active' : ''}`} onClick={handleBandageClick} data-tooltip="Apply Bandage">
              <i className="fas fa-plus-circle"></i>
              <span className="action-tooltip">Bandages</span>
            </div>
            <div className={`action-button ${showTreatmentsPanel ? 'treatments-active' : ''}`} onClick={handleTreatmentsClick} data-tooltip="View Active Treatments">
              <i className="fas fa-list-alt"></i>
              <span className="action-tooltip">Active Treatments</span>
            </div>
            <div className={`action-button ${showTourniquetPanel ? 'tourniquet-active' : ''}`} onClick={handleTourniquetClick} data-tooltip="Apply Tourniquet">
              <i className="fas fa-compress"></i>
              <span className="action-tooltip">Tourniquets</span>
            </div>
          </div>
        </div>
      </div>

      {/* Bandage Selection Panel */}
      {showBandagePanel && (
        <div className="bandage-selection-panel" style={{
          position: 'fixed',
          top: '5vh',
          right: '2vw', 
          width: '22vw',
          height: '30vh',
          zIndex: 10000,
          animation: 'slideInFromRight 0.3s ease-out'
        }}>
          <div className="treatments-detail-bg" style={{
            backgroundImage: `url(${weatheredPaper})`,
            backgroundSize: '100% 100%',
            backgroundRepeat: 'no-repeat',
            backgroundPosition: 'center',
            width: '100%',
            height: '100%',
            padding: '20px',
            borderRadius: '10px',
            boxShadow: 'none'
          }}>
            <div className="treatments-detail-header">
              <div className="treatments-detail-title" style={{ color: 'white', fontWeight: 'bold' }}>APPLY BANDAGE</div>
              <div className="treatments-detail-subtitle" style={{ color: 'white' }}>
                {selectedBodyPart ? 'Select Bandage Type' : 'Select Body Part'}
              </div>
              <div className="treatments-close-btn" onClick={closePanels} style={{ 
                position: 'absolute', 
                top: '10px', 
                right: '15px', 
                fontSize: '20px', 
                color: 'white', 
                cursor: 'pointer' 
              }}>&times;</div>
            </div>
            <div className="treatments-detail-content" style={{
              marginTop: '20px',
              maxHeight: '70%',
              overflowY: 'auto',
              color: 'white'
            }}>
              {loadingInventory ? (
                // STATE 1: LOADING
                <div style={{ textAlign: 'center', padding: '40px 20px', color: 'white' }}>
                  <div style={{
                    border: '4px solid rgba(255,255,255,0.3)',
                    borderTop: '4px solid white',
                    borderRadius: '50%',
                    width: '40px',
                    height: '40px',
                    animation: 'spin 1s linear infinite',
                    margin: '0 auto 20px'
                  }}></div>
                  <p style={{ fontStyle: 'italic' }}>Checking your supplies...</p>
                </div>
              ) : !currentWounds || Object.keys(currentWounds).length === 0 ? (
                // STATE 2: NO WOUNDS
                <div style={{
                  textAlign: 'center',
                  padding: '40px 20px',
                  color: '#90EE90',
                  fontStyle: 'italic'
                }}>
                  <p style={{ fontSize: '16px', marginBottom: '10px' }}>You're lookin' spick and span here partner!</p>
                  <p style={{ fontSize: '14px' }}>No bandages needed at this time.</p>
                </div>
              ) : (
                // STATE 3: WOUNDS FOUND - SHOW OPTIONS
                <>
                  {Object.entries(currentWounds).map(([bodyPart, wound]: [string, any]) => {
                    const hasBandages = currentInventory?.bandages && currentInventory.bandages.length > 0;
                    const isDisabled = !hasBandages;

                    return (
                      <div
                        key={bodyPart}
                        className={`treatment-item ${isDisabled ? 'disabled' : ''}`}
                        onClick={() => {
                          if (hasBandages) {
                            const bandage = currentInventory.bandages[0];
                            fetch(`https://${(window as any).GetParentResourceName?.() || 'qc-advancedmedic'}/apply-bandage`, {
                              method: 'POST',
                              headers: { 'Content-Type': 'application/json' },
                              body: JSON.stringify({
                                bodyPart: bodyPart,
                                bandageType: bandage.itemName
                              })
                            }).catch(() => {});
                            closePanels();
                          }
                        }}
                        style={{
                          padding: '10px',
                          margin: '6px 0',
                          border: 'none',
                          borderRadius: '5px',
                          cursor: isDisabled ? 'not-allowed' : 'pointer',
                          backgroundImage: `url(${selectionBoxBg})`,
                          backgroundSize: '100% 100%',
                          backgroundRepeat: 'no-repeat',
                          backgroundPosition: 'center',
                          transition: 'all 0.2s ease',
                          color: isDisabled ? '#666' : 'white',
                          minHeight: '55px',
                          opacity: isDisabled ? 0.4 : 1,
                          filter: isDisabled ? 'grayscale(100%)' : 'none'
                        }}
                      >
                        {hasBandages ? (
                          <>
                            <div style={{ fontWeight: 'bold', marginBottom: '5px' }}>
                              🩹 {currentInventory.bandages[0].label} - {bodyPart.toUpperCase()}
                            </div>
                            <div style={{ fontSize: '11px', color: '#f39c12' }}>
                              Bleeding: Level {wound.bleedingLevel || 0}
                            </div>
                          </>
                        ) : (
                          <>
                            <div style={{ fontWeight: 'bold', marginBottom: '5px', color: '#666' }}>
                              🩹 ???? - {bodyPart.toUpperCase()}
                            </div>
                            <div style={{ fontSize: '11px', color: '#999', fontStyle: 'italic' }}>
                              (No bandages in inventory)
                            </div>
                          </>
                        )}
                      </div>
                    );
                  })}
                </>
              )}
            </div>
          </div>
        </div>
      )}

      {/* Tourniquet Selection Panel */}
      {showTourniquetPanel && (
        <div className="tourniquet-selection-panel" style={{
          position: 'fixed',
          top: '60vh', // Lower position near bottom (treatments panel is at 30vh)
          right: '2vw', 
          width: '22vw',
          height: '30vh',
          zIndex: 10000,
          animation: 'slideInFromRight 0.3s ease-out'
        }}>
          <div className="treatments-detail-bg" style={{
            backgroundImage: `url(${weatheredPaper})`,
            backgroundSize: '100% 100%',
            backgroundRepeat: 'no-repeat',
            backgroundPosition: 'center',
            width: '100%',
            height: '100%',
            padding: '20px',
            borderRadius: '10px',
            boxShadow: 'none'
          }}>
            <div className="treatments-detail-header">
              <div className="treatments-detail-title" style={{ color: 'white', fontWeight: 'bold' }}>APPLY TOURNIQUET</div>
              <div className="treatments-detail-subtitle" style={{ color: 'white' }}>
                {selectedTourniquetBodyPart ? 'Select Tourniquet Type' : 'Select Severely Bleeding Part'}
              </div>
              <div className="treatments-close-btn" onClick={closePanels} style={{ 
                position: 'absolute', 
                top: '10px', 
                right: '15px', 
                fontSize: '20px', 
                color: 'white', 
                cursor: 'pointer' 
              }}>&times;</div>
            </div>
            <div className="treatments-detail-content" style={{
              marginTop: '20px',
              maxHeight: '70%',
              overflowY: 'auto',
              color: 'white'
            }}>
              {loadingInventory ? (
                // STATE 1: LOADING
                <div style={{ textAlign: 'center', padding: '40px 20px', color: 'white' }}>
                  <div style={{
                    border: '4px solid rgba(255,255,255,0.3)',
                    borderTop: '4px solid white',
                    borderRadius: '50%',
                    width: '40px',
                    height: '40px',
                    animation: 'spin 1s linear infinite',
                    margin: '0 auto 20px'
                  }}></div>
                  <p style={{ fontStyle: 'italic' }}>Checking your supplies...</p>
                </div>
              ) : !currentWounds || Object.entries(currentWounds).filter(([_, wound]: [string, any]) => (wound.bleedingLevel || 0) >= 6).length === 0 ? (
                // STATE 2: NO SEVERE BLEEDING
                <div style={{
                  textAlign: 'center',
                  padding: '40px 20px',
                  color: '#90EE90',
                  fontStyle: 'italic'
                }}>
                  <p style={{ fontSize: '16px', marginBottom: '10px' }}>Ain't no severe bleedin' here!</p>
                  <p style={{ fontSize: '14px' }}>No tourniquets needed right now.</p>
                </div>
              ) : (
                // STATE 3: SEVERE BLEEDING FOUND - SHOW OPTIONS
                <>
                  {Object.entries(currentWounds).filter(([_, wound]: [string, any]) => (wound.bleedingLevel || 0) >= 6).map(([bodyPart, wound]: [string, any]) => {
                    const hasTourniquets = currentInventory?.tourniquets && currentInventory.tourniquets.length > 0;
                    const isDisabled = !hasTourniquets;

                    return (
                      <div
                        key={bodyPart}
                        className={`treatment-item ${isDisabled ? 'disabled' : ''}`}
                        onClick={() => {
                          if (hasTourniquets) {
                            const tourniquet = currentInventory.tourniquets[0];
                            fetch(`https://${(window as any).GetParentResourceName?.() || 'qc-advancedmedic'}/apply-tourniquet`, {
                              method: 'POST',
                              headers: { 'Content-Type': 'application/json' },
                              body: JSON.stringify({
                                bodyPart: bodyPart,
                                tourniquetType: tourniquet.itemName
                              })
                            }).catch(() => {});
                            closePanels();
                          }
                        }}
                        style={{
                          padding: '10px',
                          margin: '6px 0',
                          border: 'none',
                          borderRadius: '5px',
                          cursor: isDisabled ? 'not-allowed' : 'pointer',
                          backgroundImage: `url(${selectionBoxBg})`,
                          backgroundSize: '100% 100%',
                          backgroundRepeat: 'no-repeat',
                          backgroundPosition: 'center',
                          transition: 'all 0.2s ease',
                          color: isDisabled ? '#666' : 'white',
                          minHeight: '55px',
                          opacity: isDisabled ? 0.4 : 1,
                          filter: isDisabled ? 'grayscale(100%)' : 'none'
                        }}
                      >
                        {hasTourniquets ? (
                          <>
                            <div style={{ fontWeight: 'bold', marginBottom: '5px' }}>
                              🩸 {currentInventory.tourniquets[0].label} - {bodyPart.toUpperCase()}
                            </div>
                            <div style={{ fontSize: '11px', color: '#e74c3c', fontWeight: 'bold' }}>
                              SEVERE BLEEDING: Level {wound.bleedingLevel || 0}
                            </div>
                          </>
                        ) : (
                          <>
                            <div style={{ fontWeight: 'bold', marginBottom: '5px', color: '#666' }}>
                              🩸 ???? - {bodyPart.toUpperCase()}
                            </div>
                            <div style={{ fontSize: '11px', color: '#999', fontStyle: 'italic' }}>
                              (No tourniquets in inventory)
                            </div>
                          </>
                        )}
                      </div>
                    );
                  })}
                </>
              )}
            </div>
          </div>
        </div>
      )}

      {/* Active Treatments Panel */}
      {showTreatmentsPanel && (
          <div className="treatments-selection-panel" style={{
          position: 'fixed',
          top: '30vh', // Lower position than bandage panel (was 15vh)
          right: '2vw', 
          width: '22vw',
          height: '30vh',
          zIndex: 10000,
          animation: 'slideInFromRight 0.3s ease-out'
        }}>
          <div className="treatments-detail-bg" style={{
            backgroundImage: `url(${weatheredPaper})`,
            backgroundSize: '100% 100%',
            backgroundRepeat: 'no-repeat',
            backgroundPosition: 'center',
            width: '100%',
            height: '100%',
            padding: '20px',
            borderRadius: '10px',
            boxShadow: 'none'
          }}>
            <div className="treatments-detail-header">
              <div className="treatments-detail-title" style={{ color: 'white', fontWeight: 'bold' }}>ACTIVE TREATMENTS</div>
              <div className="treatments-detail-subtitle" style={{ color: 'white' }}>
                Manage your current treatments
              </div>
              <div className="treatments-close-btn" onClick={closePanels} style={{ 
                position: 'absolute', 
                top: '10px', 
                right: '15px', 
                fontSize: '20px', 
                color: 'white', 
                cursor: 'pointer' 
              }}>&times;</div>
            </div>
            <div className="treatments-detail-content" style={{ 
              marginTop: '20px', 
              maxHeight: '70%', 
              overflowY: 'auto',
              color: 'white'
            }}>
              
              {treatments.length === 0 ? (
                <div style={{ 
                  textAlign: 'center', 
                  padding: '20px', 
                  color: 'white',
                  fontStyle: 'italic'
                }}>
                  No active treatments
                </div>
              ) : (
                treatments.map((treatment, index) => (
                  <div key={index} className="treatment-option" style={{
                    padding: '10px',
                    margin: '6px 0',
                    border: 'none',
                    borderRadius: '5px',
                    backgroundImage: `url(${selectionBoxBg})`,
                    backgroundSize: '100% 100%',
                    backgroundRepeat: 'no-repeat',
                    backgroundPosition: 'center',
                    transition: 'all 0.2s ease',
                    color: 'white',
                    minHeight: '55px',
                    display: 'flex',
                    flexDirection: 'column',
                    position: 'relative'
                  }}>
                    <div style={{ fontWeight: 'bold', marginBottom: '8px', display: 'flex', justifyContent: 'space-between', alignItems: 'center' }}>
                      <span>{treatment.bodyPart?.toUpperCase() || 'UNKNOWN'}</span>
                      <span style={{ fontSize: '12px', color: '#90EE90' }}>
                        {treatment.type === 'bandage' ? 'Bandaged' : treatment.type?.toUpperCase()}
                      </span>
                    </div>
                    <div style={{ fontSize: '11px', color: '#D3D3D3', marginBottom: '8px' }}>
                      Item: {treatment.itemType || 'Unknown'} | Applied: {treatment.appliedBy || 'Self'}
                    </div>
                    <div style={{ display: 'flex', gap: '5px', justifyContent: 'flex-end' }}>
                      <button onClick={() => {
                        // Send replace bandage request
                        fetch(`https://${(window as any).GetParentResourceName?.() || 'qc-advancedmedic'}/replace-treatment`, {
                          method: 'POST',
                          headers: { 'Content-Type': 'application/json' },
                          body: JSON.stringify({ 
                            bodyPart: treatment.bodyPart, 
                            treatmentType: treatment.type 
                          })
                        }).catch(() => {});
                      }} style={{
                        padding: '4px 8px',
                        fontSize: '10px',
                        backgroundImage: `url(${selectionBoxBg})`,
                        backgroundSize: '100% 100%',
                        border: 'none',
                        borderRadius: '3px',
                        color: '#f39c12',
                        cursor: 'pointer',
                        transition: 'all 0.2s ease'
                      }}>
                        Replace
                      </button>
                      
                      {/* Show Remove button only if wound is healed (no wound exists for this body part) */}
                      {!wounds[treatment.bodyPart] && (
                        <button onClick={() => {
                          // Send remove treatment request
                          fetch(`https://${(window as any).GetParentResourceName?.() || 'qc-advancedmedic'}/remove-treatment`, {
                            method: 'POST',
                            headers: { 'Content-Type': 'application/json' },
                            body: JSON.stringify({ 
                              bodyPart: treatment.bodyPart, 
                              treatmentType: treatment.type 
                            })
                          }).catch(() => {});
                        }} style={{
                          padding: '4px 8px',
                          fontSize: '10px',
                          backgroundImage: `url(${selectionBoxBg})`,
                          backgroundSize: '100% 100%',
                          border: 'none',
                          borderRadius: '3px',
                          color: '#e74c3c',
                          cursor: 'pointer',
                          transition: 'all 0.2s ease'
                        }}>
                          Remove
                        </button>
                      )}
                    </div>
                  </div>
                ))
              )}
            </div>
          </div>
        </div>
      )}
    </>
  );
};

export default MedicalPanel;