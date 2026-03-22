export interface BehaviorProfile {
    typing_speed: number;
    swipe_velocity: number;
    touch_pressure: number;
}

export class BehaviorService {
    behaviorMismatch(profile: BehaviorProfile, login: BehaviorProfile): boolean {
        // Simple heuristic: if typing speed varies by more than 100ms, flag it
        const diff = Math.abs(profile.typing_speed - login.typing_speed);
        if (diff > 100) return true;
        
        // Add more complex checks for swipe and pressure if needed
        return false;
    }
}

export const Behavior = new BehaviorService();
