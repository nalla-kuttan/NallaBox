// Game inputs made while the phone is offline. After reconnecting, each is sent once if it still
// belongs to the screen and round the room is on; anything for another round is dropped.

const SCREENS = {
  submit_text: ['R1'],
  stroke_data: ['C2-artist'],
  cast_vote: ['R3', 'C3-witness', 'C5', 'I5'],
  place_bet: ['I3'],
};

export function createOutbox() {
  let items = [];
  return {
    queue(type, fields) {
      items = items.filter((i) => i.type !== type);
      items.push({ type, fields });
    },
    get size() { return items.length; },
    flush(view, send) {
      if (!view?.data) return;
      const keep = [];
      for (const i of items) {
        const sameRound = i.fields.round === view.data.round;
        if (sameRound && SCREENS[i.type]?.includes(view.screen)) send(i.type, i.fields);
        else if (sameRound) keep.push(i);
      }
      items = keep;
    },
  };
}
