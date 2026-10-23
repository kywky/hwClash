export const initCore: (homeDir: string) => string;

export const startCore: (
  tunFd: number,
  optionsJson: string,
  protect: (id: number, fd: number) => void
) => Promise<string>;

export const stopCore: () => void;

export const getCoreStatus: () => string;

export const notifyProtected: (id: number) => void;
