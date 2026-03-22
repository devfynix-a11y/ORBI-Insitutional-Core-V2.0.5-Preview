export interface RiskData {
    newDevice: boolean;
    newLocation: boolean;
    vpnDetected: boolean;
    behaviorMismatch: boolean;
}

export class RiskService {
    calculateRisk(data: RiskData): number {
        let score = 0;
        if (data.newDevice) score += 30;
        if (data.newLocation) score += 20;
        if (data.vpnDetected) score += 40;
        if (data.behaviorMismatch) score += 25;

        console.log(`[RiskService] Risk factors evaluated:
            New_Device=${data.newDevice} (+30)
            New_Location=${data.newLocation} (+20)
            VPN_Detected=${data.vpnDetected} (+40)
            Behavior_Mismatch=${data.behaviorMismatch} (+25)
            Final_Score=${score}
        `);

        return score;
    }

    getDecision(score: number): 'ALLOW' | 'REQUIRE_OTP' | 'BLOCK' {
        if (score < 30) return 'ALLOW';
        if (score <= 60) return 'REQUIRE_OTP';
        return 'BLOCK';
    }
}

export const Risk = new RiskService();
