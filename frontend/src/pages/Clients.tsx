import React, { useState, useEffect } from 'react';
import { supabase } from '../services/supabase';

export const Clients: React.FC = () => {
  const [clients, setClients] = useState<any[]>([]);
  const [loading, setLoading] = useState(true);

  useEffect(() => {
    const fetch = async () => {
      const { data } = await supabase.from('clients').select('*');
      if (data) setClients(data);
      setLoading(false);
    };
    fetch();
  }, []);

  if (loading) return <div>Cargando clientes...</div>;

  return (
    <div className="p-6">
      <h2 className="text-2xl font-bold mb-4">Clientes</h2>
      <div className="bg-white shadow rounded-lg overflow-hidden">
        <table className="min-w-full divide-y divide-gray-200">
          <thead className="bg-gray-50">
            <tr>
              <th className="px-6 py-3 text-left text-xs font-medium text-gray-500 uppercase">Nombre</th>
              <th className="px-6 py-3 text-left text-xs font-medium text-gray-500 uppercase">Habeas Data</th>
            </tr>
          </thead>
          <tbody className="bg-white divide-y divide-gray-200">
            {clients.map(c => (
              <tr key={c.id}>
                <td className="px-6 py-4">{c.full_name}</td>
                <td className="px-6 py-4">
                  <span className={`px-2 py-1 rounded text-xs ${c.habeas_data_authorized ? 'bg-green-100 text-green-800' : 'bg-red-100 text-red-800'}`}>
                    {c.habeas_data_authorized ? 'Autorizado' : 'Pendiente'}
                  </span>
                </td>
              </tr>
            ))}
          </tbody>
        </table>
      </div>
    </div>
  );
};
