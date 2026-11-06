import React from 'react';
import ForgeReconciler, { Text } from '@forge/react';
const App = ({ label }) => (<Text>{label}</Text>);
ForgeReconciler.render(<App label="Hello" />);
