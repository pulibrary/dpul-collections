import React from 'react';

const Loader = () => {
  return (
    <img alt="Loading Viewer" 
         src="/images/spinning-circles.svg" 
         style={{ 
            width: '150px', 
            position: 'absolute', 
            top: '50%', 
            left: '50%', 
            transform: 'translate(-50%, -50%)' 
        }}/>
  );
};

export default Loader;