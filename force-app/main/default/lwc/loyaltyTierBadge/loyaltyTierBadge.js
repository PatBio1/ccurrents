import { LightningElement, api } from 'lwc';
import PROESIS_LOYALTY_BADGES from '@salesforce/resourceUrl/Proesis_Loyalty_Badges';

// Seems like there was a mismatch on the order. The order provided to the UX team is different than the order configured in org data
const loyaltyTierNameToBadgeFileName = new Map([
    ["Donor (Default)", "default"],
    ["Normal Donor +15", "normal"],
    ["Signature", "VIP"],
    ["VIP", "royal"],
    ["Royal", "signature"]
]);

export default class LoyaltyTierBadge extends LightningElement {
    @api width;
    @api height;
    @api loyaltyTierName;

    currentBadgeFileName;

    get badgeWidth() {
        return this.width || "32px";
    }

    get badgeHeight() {
        return this.height || "32px";
    }

    get fullBadgeFilePath() {
        return `${PROESIS_LOYALTY_BADGES}/badges/${this.currentBadgeFileName}.svg`;
    }

    renderedCallback() {
        let targetBadgeFileName = loyaltyTierNameToBadgeFileName.get(this.loyaltyTierName);
        if (!targetBadgeFileName) {
            targetBadgeFileName = "default";
        }

        if (targetBadgeFileName !== this.currentBadgeFileName) {
            this.currentBadgeFileName = targetBadgeFileName;
        }
    }
}