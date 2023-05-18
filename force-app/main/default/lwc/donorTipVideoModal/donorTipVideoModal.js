import { LightningElement, api } from 'lwc';
import LightningModal from 'lightning/modal';

export default class DonorTipVideoModal extends LightningModal {
    @api linkText;
    @api youtubeVideoUrl;
}