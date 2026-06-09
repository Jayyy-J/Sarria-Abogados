import React, { useState, useEffect } from 'react';
import { supabase } from '../services/supabase';

export const Finance: React.FC = () => {
  const [invoices, setInvoices] = useState<any[]>([]);

  useEffect(() => {
    const fetch = async () => {
      const { data } = await supabase.from('invoices').select('*, cases(title)');
      if (data) setInvoices(data);
    };
    fetch();
  }, []);

  const total = invoices.reduce((acc, curr) => acc + Number(curr.amount), 0);

  return (
    <div className="p-6">
      <h2 className="text-2xl font-bold mb-4">Finanzas</h2>
      <div className="grid grid-cols-1 md:grid-cols-2 gap-4 mb-6">
        <div className="bg-white p-4 shadow rounded border-l-4 border-green-500">
          <p className="text-sm text-gray-500">Total Facturado</p>
          <p className="text-xl font-bold">$ {total.toLocaleString()}</p>
        </div>
      </div>
      <div className="bg-white shadow rounded overflow-hidden">
        <table className="min-w-full divide-y divide-gray-200">
          <thead className="bg-gray-50">
            <tr>
              <th className="px-6 py-3 text-left text-xs font-medium text-gray-500 uppercase">Caso</th>
              <th className="px-6 py-3 text-left text-xs font-medium text-gray-500 uppercase">Monto</th>
              <th className="px-6 py-3 text-left text-xs font-medium text-gray-500 uppercase">Estado</th>
            </tr>
          </thead>
          <tbody className="bg-white divide-y divide-gray-200">
            {invoices.map(i => (
              <tr key={i.id}>
                <td className="px-6 py-4">{i.cases?.title}</td>
                <td className="px-6 py-4">$ {Number(i.amount).toLocaleString()}</td>
                <td className="px-6 py-4 capitalize">{i.status}</td>
              </tr>
            ))}
          </tbody>
        </table>
      </div>
    </div>
  );
};
