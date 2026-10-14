import { useState } from 'react';

const API = import.meta.env.VITE_API_URL ?? 'http://localhost:5000';
const STEPS = ['Company', 'Financials', 'Review'];

export default function AccountWizard({ fetchImpl = fetch }) {
  const [step, setStep] = useState(0);
  const [name, setName] = useState('');
  const [revenue, setRevenue] = useState('');
  const [error, setError] = useState(null);
  const [createdId, setCreatedId] = useState(null);
  const [submitting, setSubmitting] = useState(false);

  const revenueNumber = Number(revenue);
  const stepError =
    step === 0 && !name.trim() ? 'Company name is required'
    : step === 1 && (revenue === '' || Number.isNaN(revenueNumber) || revenueNumber < 0)
      ? 'Enter a revenue of 0 or more'
      : null;

  function next() {
    if (stepError) return setError(stepError);
    setError(null);
    setStep((s) => s + 1);
  }

  async function submit() {
    setSubmitting(true);
    setError(null);
    try {
      const res = await fetchImpl(`${API}/api/accounts`, {
        method: 'POST',
        headers: { 'Content-Type': 'application/json' },
        body: JSON.stringify({ name: name.trim(), annualRevenue: revenueNumber }),
      });
      if (!res.ok) throw new Error('Request failed');
      setCreatedId((await res.json()).id);
    } catch {
      setError('Could not create the account');
    } finally {
      setSubmitting(false);
    }
  }

  if (createdId) {
    return (
      <section>
        <h2>Account created</h2>
        <p>Reference: <span data-testid="account-id">{createdId}</span></p>
      </section>
    );
  }

  return (
    <section aria-label="New account">
      <h2>New account: step {step + 1} of {STEPS.length} ({STEPS[step]})</h2>

      {step === 0 && (
        <label>
          Company name
          <input value={name} onChange={(e) => setName(e.target.value)} />
        </label>
      )}
      {step === 1 && (
        <label>
          Annual revenue
          <input value={revenue} onChange={(e) => setRevenue(e.target.value)} inputMode="numeric" />
        </label>
      )}
      {step === 2 && (
        <dl>
          <dt>Company</dt><dd data-testid="review-name">{name}</dd>
          <dt>Annual revenue</dt><dd data-testid="review-revenue">{revenueNumber}</dd>
        </dl>
      )}

      {error && <p role="alert">{error}</p>}

      {step > 0 && <button type="button" onClick={() => { setError(null); setStep(step - 1); }}>Back</button>}
      {step < STEPS.length - 1 && <button type="button" onClick={next}>Next</button>}
      {step === STEPS.length - 1 && (
        <button type="button" onClick={submit} disabled={submitting}>Create account</button>
      )}
    </section>
  );
}
