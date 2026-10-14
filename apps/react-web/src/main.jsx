import React from 'react';
import { createRoot } from 'react-dom/client';
import AccountWizard from './AccountWizard.jsx';
import RatingForm from './RatingForm.jsx';

createRoot(document.getElementById('root')).render(
  <>
    <AccountWizard />
    <hr />
    <RatingForm />
  </>
);
