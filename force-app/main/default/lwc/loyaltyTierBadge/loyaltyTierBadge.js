import { LightningElement, api } from 'lwc';
import PROESIS_LOYALTY_BADGES from '@salesforce/resourceUrl/Proesis_Loyalty_Badges';

import getLoyaltyBadgeDisplaySettings from '@salesforce/apex/LoyaltyLevelService.getLoyaltyBadgeDisplaySettings';

// Seems like there was a mismatch on the order. The order provided to the UX team is different than the order configured in org data
// const loyaltyTierNameToBadgeFileName = new Map([
//     ["Donor (Default)", "default"],
//     ["Normal Donor +15", "normal"],
//     ["Signature", "VIP"],
//     ["VIP", "royal"],
//     ["Royal", "signature"]
// ]);

export default class LoyaltyTierBadge extends LightningElement {
    @api width;
    @api height;
    @api loyaltyTierName;

    badgeSettings;
    currentBadgeFileName;
    isInitialized = false;

    get badgeWidth() {
        return this.width || "32px";
    }

    get badgeHeight() {
        return this.height || "32px";
    }

    get fullBadgeFilePath() {
        if (!this.currentBadgeFileName) {
            return '';
        }

        return `${PROESIS_LOYALTY_BADGES}/badges/${this.currentBadgeFileName}.svg`;
    }

    async renderedCallback() {
        if (!this.isInitialized) {
            try {
                this.badgeSettings = await getLoyaltyBadgeDisplaySettings();
                this.isInitialized = true;
            } catch(e) {
                console.error(e);
            }
        }

        if (this.isInitialized) {
            let targetBadgeFileName = this.badgeSettings.find(badgeSetting => badgeSetting.badgeName === this.loyaltyTierName)?.badgeFileName;
            if (targetBadgeFileName && targetBadgeFileName !== this.currentBadgeFileName) {
                this.currentBadgeFileName = targetBadgeFileName;
            }
        }
    }
}