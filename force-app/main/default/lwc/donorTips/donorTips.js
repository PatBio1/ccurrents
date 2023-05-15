import { LightningElement } from 'lwc';
import labels from 'c/labelService';

import DonorTipVideoModal from 'c/donorTipVideoModal';

const AVAILABLE_TIP_LINKS = {
    sections: [
        {
            title: labels.learnMoreSectionTitle,
            links: [
                {
                    linkText: labels.donorTipDonorIdReqsText,
                    youtubeVideoId: labels.donorTipDonorIdReqsVideoId // English vs Spanish links are different, will be handled via translations
                },
                {
                    linkText: labels.donorTipApptRulesText,
                    youtubeVideoId: labels.donorTipApptRulesVideoId
                },
                {
                    linkText: labels.donorTipDonationProcessText,
                    youtubeVideoId: labels.donorTipDonationProcessVideoId
                },
                {
                    linkText: labels.donorTipHealthHistoryText,
                    youtubeVideoId: labels.donorTipHealthHistoryVideoId
                }
            ]
        },
        {
            title: labels.newDonorSectionTitle,
            links: [
                {
                    linkText: labels.donorTipFirstAppointmentText,
                    youtubeVideoId: labels.donorTipFirstAppointmentVideoId
                },
                {
                    linkText: labels.donorTipLoyaltyProgramText,
                    youtubeVideoId: labels.donorTipLoyaltyProgramVideoId
                },
                {
                    linkText: labels.donorTipHealthHistoryOnlineText,
                    youtubeVideoId: labels.donorTipHealthHistoryOnlineVideoId
                },
                {
                    linkText: labels.donorTipRedeemingPointsText,
                    youtubeVideoId: labels.donorTipRedeemingPointsVideoId
                },
                {
                    linkText: labels.donorTipDonationDayText,
                    youtubeVideoId: labels.donorTipDonationDayVideoId
                }
            ]
        }
    ]
}

export default class DonorTips extends LightningElement {

    labels = labels;
    tipLinks = AVAILABLE_TIP_LINKS;


    handleSelectDonorTip(event) {
        let targetYoutubeId = event.currentTarget.dataset.tipLinkId;

        DonorTipVideoModal.open({
            linkText: event.currentTarget.innerText,
            youtubeVideoId: targetYoutubeId
        });
    }
}