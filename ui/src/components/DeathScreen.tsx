import React, { useState, useEffect } from 'react';

// FiveM/RedM global function
declare global {
  function GetParentResourceName(): string;
}

interface DeathScreenProps {
  message: string;
  seconds: number;
  canRespawn?: boolean;
  medicsOnDuty?: number;
}

const DeathScreen: React.FC<DeathScreenProps> = ({ message, seconds, canRespawn = false, medicsOnDuty = 0 }) => {
  const [timeLeft, setTimeLeft] = useState(seconds);
  const [canDisableFocus, setCanDisableFocus] = useState(false);

  useEffect(() => {
    setTimeLeft(seconds);
  }, [seconds]);

  useEffect(() => {
    // Add longer delay before allowing right-click to disable focus
    // This prevents the same right-click that enabled focus from immediately disabling it
    const timer = setTimeout(() => {
      setCanDisableFocus(true);
    }, 1000); // 1000ms delay (1 second)

    return () => clearTimeout(timer);
  }, []);

  useEffect(() => {
    const handleRightClick = (e: MouseEvent) => {
      if (e.button === 2 && canDisableFocus) { // Right mouse button with delay check
        e.preventDefault();
        
        // Send message to client to disable NUI focus
        fetch(`https://${GetParentResourceName()}/disable-nui-focus`, {
          method: 'POST',
          headers: { 'Content-Type': 'application/json' },
          body: JSON.stringify({})
        });
      }
    };

    // Add event listener for right-click when NUI has focus
    document.addEventListener('contextmenu', handleRightClick);
    
    return () => {
      document.removeEventListener('contextmenu', handleRightClick);
    };
  }, [canDisableFocus]);

  useEffect(() => {
    if (timeLeft <= 0) return;

    const timer = setInterval(() => {
      setTimeLeft(prev => {
        const newTime = Math.max(0, prev - 1);
        if (newTime === 0) {
          // Notify client that timer finished
          fetch(`https://${GetParentResourceName()}/death-timer-finished`, {
            method: 'POST',
            headers: { 'Content-Type': 'application/json' },
            body: JSON.stringify({})
          });
        }
        return newTime;
      });
    }, 1000);

    return () => clearInterval(timer);
  }, [timeLeft]);

  const handleRespawn = () => {
    fetch(`https://${GetParentResourceName()}/death-respawn`, {
      method: 'POST',
      headers: { 'Content-Type': 'application/json' },
      body: JSON.stringify({})
    });
  };

  const handleCallMedic = () => {
    fetch(`https://${GetParentResourceName()}/death-call-medic`, {
      method: 'POST',
      headers: { 'Content-Type': 'application/json' },
      body: JSON.stringify({})
    });
  };

  const formatTime = (totalSeconds: number) => {
    const minutes = Math.floor(totalSeconds / 60);
    const seconds = totalSeconds % 60;
    return {
      minuteFirst: Math.floor(minutes / 10),
      minuteSecond: minutes % 10,
      secondFirst: Math.floor(seconds / 10),
      secondSecond: seconds % 10
    };
  };

  const time = formatTime(timeLeft);

  return (
    <div id="deathscreen">
      <div id="countdown">
        {/* Skull Icon - Now Red */}
        <div style={{ display: 'flex', alignItems: 'center', justifyContent: 'center', marginBottom: '20px' }}>
          <svg xmlns="http://www.w3.org/2000/svg" width="31" height="36" viewBox="0 0 31 36" fill="none" style={{ opacity: 0.8 }}>
            <path d="M15.529 0C6.04979 0 -1.98684 9.38916 0.436145 18.6019C1.02587 20.8462 1.64746 22.9057 2.37038 24.7478C1.22602 26.0266 1.7205 28.4958 2.80936 29.6878C3.47714 30.4182 4.96917 31.6742 6.22094 32.1854C7.23353 32.0364 10.1957 31.8686 10.0124 35.0197C10.3558 35.1601 10.7153 35.2818 11.0859 35.392V34.146H11.5324V35.5147C12.1325 35.6684 12.7602 35.7876 13.4143 35.8672V34.146H13.8594V35.9111C14.4656 35.9687 15.0872 36 15.7256 36C15.731 36 15.7367 36 15.7421 36V34.1453H16.1879V35.9914C16.8231 35.9777 17.4461 35.9388 18.0455 35.8657V34.1453H18.4923V35.8013C19.115 35.7088 19.7129 35.5824 20.2823 35.419V34.146H20.728V35.2804C20.984 35.1954 21.2333 35.1058 21.4749 35.005C20.9769 31.0673 24.9345 31.7268 25.4967 31.8395C26.791 31.4028 28.4327 30.028 29.1428 29.2518C30.2753 28.0141 30.7701 25.389 29.4417 24.1625C29.397 24.1211 29.3451 24.0923 29.2982 24.052C29.7916 22.6084 30.2273 21.0272 30.6323 19.305C32.8089 10.0303 25.0079 0 15.529 0ZM11.8951 23.6189C10.2663 24.8054 8.49676 27.0918 6.32513 25.7652C4.15279 24.4386 4.10266 19.5696 5.37735 17.6375C6.47194 15.9768 12.7469 16.3786 13.5551 17.7721C14.3635 19.1653 13.5235 22.4323 11.8951 23.6189ZM17.6856 29.4689C17.4858 30.0733 16.2434 29.2781 15.6869 28.885C15.1312 29.2781 13.888 30.0737 13.6879 29.4689C13.4287 28.6859 15.0492 23.8046 15.2444 23.4104C15.3024 23.2931 15.3894 23.1926 15.4821 23.1196C15.5287 23.0425 15.5953 23.0119 15.6726 23.0195C15.678 23.0184 15.6819 23.0202 15.6873 23.0195C15.6923 23.0202 15.6966 23.0184 15.702 23.0195C15.7793 23.0119 15.8459 23.0429 15.8928 23.1199C15.9859 23.1923 16.0726 23.2927 16.1295 23.4104C16.3236 23.8043 17.9452 28.6862 17.6856 29.4689ZM25.4129 25.3768C23.3333 26.8452 21.4162 24.6816 19.7129 23.6081C18.0086 22.5346 16.9552 19.3295 17.6706 17.8848C18.3845 16.4408 24.6194 15.6197 25.8214 17.2026C27.2196 19.0458 27.491 23.9069 25.4129 25.3768Z" fill="#dc3545"/>
          </svg>
        </div>
        
        {/* Status Text */}
        <div style={{ marginBottom: '30px', textAlign: 'center' }}>
          <h4 style={{ 
            fontSize: '48px', 
            color: '#dc3545',
            textShadow: 'none',
            margin: '0 0 15px 0' 
          }}>
            Disabled
          </h4>
          <h4 style={{ color: '#52575c', fontSize: '16px', margin: 0 }}>{message}</h4>
        </div>

        {/* Timer Numbers */}
        <div style={{ display: 'flex', alignItems: 'center', justifyContent: 'center', gap: '15px', marginBottom: '15px' }}>
          <div className="countdiv"><h4>{time.minuteFirst}</h4></div>
          <div className="countdiv"><h4>{time.minuteSecond}</h4></div>
          <div className="countdiv" style={{ background: 'transparent', width: '5%' }}><h4>:</h4></div>
          <div className="countdiv"><h4>{time.secondFirst}</h4></div>
          <div className="countdiv"><h4>{time.secondSecond}</h4></div>
        </div>

        {/* Action buttons */}
        <div style={{ 
          display: 'flex',
          gap: '15px',
          alignItems: 'center',
          justifyContent: 'center',
          marginTop: '10px'
        }}>
          {medicsOnDuty > 0 && (
            <button
              onClick={handleCallMedic}
              className="death-button"
            >
              Call Medic ({medicsOnDuty} Available)
            </button>
          )}
          
          {(canRespawn || timeLeft === 0) && (
            <button
              onClick={handleRespawn}
              className="death-button"
            >
              {timeLeft === 0 ? 'Respawn' : 'Give Up'}
            </button>
          )}
        </div>
      </div>
    </div>
  );
};

export default DeathScreen;