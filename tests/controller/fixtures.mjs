// View fixtures shaped like the Swift engine's payloads (NallaCore RoomViews.swift).
export const players = [
  { id: 1, name: 'Priya', colour: 'saffron', connected: true, isLeader: true, score: 0 },
  { id: 2, name: 'Sam', colour: 'sky', connected: true, isLeader: false, score: 0 },
  { id: 3, name: 'Lena', colour: 'lilac', connected: true, isLeader: false, score: 0 },
];
export const settings = { timer: '1', familyFriendly: true, bannedWords: false, voiceOn: true };
export const room = { code: 'BCDF', players, leaderId: 1, settings };
export const you = (id = 1) => {
  const p = players.find((x) => x.id === id);
  return { id, name: p.name, colour: p.colour, isLeader: id === 1, isHost: false, score: 0 };
};
export const lobby = (n = 3) => ({
  code: 'BCDF', players: players.slice(0, n), leaderName: 'Priya', seats: 8,
  canStart: n >= 3, ...(n >= 3 ? {} : { startBlockedReason: 'Need 3 players to start' }),
});
export const card = (id, name, minPlayers = 3) => ({
  id, name, players: `${minPlayers}–8 players`, length: '15 min', tagline: 'Fake the missing words.',
  pitch: 'Fake the missing words. Spot the real ones.', colour: 'saffron', icon: '▮▮', minPlayers,
});
export const games = [card('redacted', 'Redacted'), card('sketch', 'Composite Sketch'), card('insider', 'Insider Trading', 4)];
export const view = (screen, data, { id = 1, deadline } = {}) => ({
  type: 'view', version: 1, screen, deadline, you: you(id), room, data,
});
