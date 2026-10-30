import React from 'react';
import ForgeReconciler, { Text } from '@forge/react';
// forge-process-env-in-ui-render
const App = () => (<Text>{process.env.FLAG}</Text>);
ForgeReconciler.render(<App />);
