import { create } from 'zustand';

interface AuthState {
  user: any;
  profile: any;
  setUser: (user: any) => void;
  setProfile: (profile: any) => void;
}

export const useAuthStore = create<AuthState>((set) => ({
  user: null,
  profile: null,
  setUser: (user) => set({ user }),
  setProfile: (profile) => set({ profile }),
}));
