import { render, screen, fireEvent, waitFor } from '@testing-library/react';
import { describe, it, expect, vi } from 'vitest';
import AccountWizard from './AccountWizard.jsx';

const type = (label, value) =>
  fireEvent.change(screen.getByLabelText(label), { target: { value } });
const click = (name) => fireEvent.click(screen.getByRole('button', { name }));

describe('AccountWizard', () => {
  it('walks three steps and posts the account', async () => {
    const fetchImpl = vi.fn().mockResolvedValue({ ok: true, json: async () => ({ id: '001ABC' }) });
    render(<AccountWizard fetchImpl={fetchImpl} />);

    type(/company name/i, '  Acme  ');
    click(/next/i);
    type(/annual revenue/i, '20000000');
    click(/next/i);
    expect(screen.getByTestId('review-name')).toHaveTextContent('Acme');
    click(/create account/i);

    await waitFor(() => expect(screen.getByTestId('account-id')).toHaveTextContent('001ABC'));
    const [url, init] = fetchImpl.mock.calls[0];
    expect(url).toMatch(/\/api\/accounts$/);
    expect(JSON.parse(init.body)).toEqual({ name: 'Acme', annualRevenue: 20000000 });
  });

  it('blocks step 1 without a company name', () => {
    render(<AccountWizard fetchImpl={vi.fn()} />);
    click(/next/i);
    expect(screen.getByRole('alert')).toHaveTextContent(/company name is required/i);
  });

  it('rejects negative or non-numeric revenue on step 2', () => {
    render(<AccountWizard fetchImpl={vi.fn()} />);
    type(/company name/i, 'Acme');
    click(/next/i);
    type(/annual revenue/i, '-5');
    click(/next/i);
    expect(screen.getByRole('alert')).toHaveTextContent(/0 or more/i);
    type(/annual revenue/i, 'abc');
    click(/next/i);
    expect(screen.getByRole('alert')).toBeInTheDocument();
  });

  it('shows an error when the API fails', async () => {
    const fetchImpl = vi.fn().mockResolvedValue({ ok: false });
    render(<AccountWizard fetchImpl={fetchImpl} />);
    type(/company name/i, 'Acme');
    click(/next/i);
    type(/annual revenue/i, '10');
    click(/next/i);
    click(/create account/i);
    await waitFor(() => expect(screen.getByRole('alert')).toHaveTextContent(/could not create/i));
  });
});
