import React, { createContext, useContext, useEffect, useState, ReactNode } from 'react';
import { onAuthStateChanged, signInWithEmailAndPassword, signOut, User } from 'firebase/auth';
import { auth } from '../services/firebase';
import { AdminService } from '../services/adminService';

interface AuthContextType {
  user: User | null;
  isAdmin: boolean;
  login: (email: string, password: string) => Promise<void>;
  logout: () => Promise<void>;
  loading: boolean;
}

const AuthContext = createContext<AuthContextType | undefined>(undefined);

export const useAuth = (): AuthContextType => {
  const context = useContext(AuthContext);
  if (context === undefined) {
    throw new Error('useAuth must be used within an AuthProvider');
  }
  return context;
};

interface AuthProviderProps {
  children: ReactNode;
}

export const AuthProvider = ({ children }: AuthProviderProps) => {
  const [user, setUser] = useState<User | null>(null);
  const [isAdmin, setIsAdmin] = useState(false);
  const [loading, setLoading] = useState(true);
  const adminService = new AdminService();

  useEffect(() => {
    const unsubscribe = onAuthStateChanged(auth, async (user) => {
      console.log('Auth state changed:', { user: !!user, uid: user?.uid, email: user?.email });
      setUser(user);
      
      if (user) {
        console.log('User logged in, checking admin status...');
        // Check if user is admin
        const adminStatus = await adminService.isAdmin(user.uid);
        console.log('Admin status result:', adminStatus);
        setIsAdmin(adminStatus);
      } else {
        console.log('No user, setting isAdmin to false');
        setIsAdmin(false);
      }
      
      setLoading(false);
      console.log('Auth state update complete');
    });

    return unsubscribe;
  }, []);

  const login = async (email: string, password: string): Promise<void> => {
    try {
      console.log('Attempting to sign in...', { email });
      
      // Add timeout and retry logic
      const loginPromise = signInWithEmailAndPassword(auth, email, password);
      const timeoutPromise = new Promise((_, reject) => 
        setTimeout(() => reject(new Error('Request timeout after 30 seconds')), 30000)
      );
      
      const userCredential = await Promise.race([loginPromise, timeoutPromise]);
      console.log('Sign in successful:', userCredential);
      
      // Don't set loading to false here - let onAuthStateChanged handle it
      
    } catch (error: any) {
      console.error('Login error:', error);
      
      // Handle specific Firebase errors
      if (error.code === 'auth/network-request-failed') {
        throw new Error('Network connection failed. Please check your internet connection and try again.');
      } else if (error.code === 'auth/user-not-found') {
        throw new Error('No admin account found with this email address.');
      } else if (error.code === 'auth/wrong-password') {
        throw new Error('Incorrect password. Please try again.');
      } else if (error.code === 'auth/invalid-email') {
        throw new Error('Invalid email address format.');
      } else if (error.code === 'auth/too-many-requests') {
        throw new Error('Too many failed attempts. Please try again later.');
      } else if (error.message === 'Request timeout after 30 seconds') {
        throw new Error('Login request timed out. Please try again.');
      } else {
        throw new Error(`Login failed: ${error.message || 'Unknown error'}`);
      }
    }
  };

  const logout = async (): Promise<void> => {
    try {
      await signOut(auth);
    } catch (error) {
      throw error;
    }
  };

  const value: AuthContextType = {
    user,
    isAdmin,
    login,
    logout,
    loading
  };

  return (
    <AuthContext.Provider value={value}>
      {children}
    </AuthContext.Provider>
  );
};
