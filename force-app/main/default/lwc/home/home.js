import { track, LightningElement } from 'lwc';
import { NavigationMixin } from 'lightning/navigation';
import labels from 'c/labelService';
import util from 'c/util';
import proesisDonor from '@salesforce/resourceUrl/ProesisDonor';
import hasFutureVisit from '@salesforce/apex/SchedulerController.hasFutureVisit';
import language from '@salesforce/i18n/lang';
import locale from '@salesforce/i18n/locale';

const PAGE_HOME = 'Home';
const PAGE_ARTICLE = 'Article';

export default class Home extends NavigationMixin(LightningElement) {

    labels = labels;
    hasRendered = false;
    loading = true;
    currentPage;

    @track articleCategories = [
        {
            name: labels.recommendedToYou,
            articles: [
                {
                    id: '1234',
                    name:'"My Donation Experience" by Jennifer Doe',
                    image: proesisDonor + '/images/portrait-of-confident-practitioner-measuring-blood-pressure-of-patient-SBI-3009082351.png',
                    bookmarked: true
                }
            ]
        }
        ,
        {
            name: labels.donorTips,
            articles: [
                {
                    id: '5678',
                    name:'Dr. Miago answers questions',
                    image: proesisDonor + '/images/portrait-of-confident-practitioner-measuring-blood-pressure-of-patient-SBI-3009082352.png',
                    bookmarked: false
                }
            ]
        }
    ];

    get showHome() {
        return (this.currentPage === PAGE_HOME);
    }

    get showArticle() {
        return (this.currentPage === PAGE_ARTICLE);
    }

    renderedCallback() {
        if (this.hasRendered) {
            return;
        }

        this.hasRendered = true;

        // If current language doesn't match the user's locale,
        // reload the page with the language from the locale.
        if (language !== locale) {
            const url = location.href + '?language=' + (locale.indexOf('es') === -1 ? 'en_US' : 'es_US');
            location.href = url;

            this.loading = false;
        } else {
            hasFutureVisit().then(response => {
                // Navigate to the schedule page if there aren't any future visits scheduled.
                if (response === true) {
                    this.currentPage = PAGE_HOME;
                } else {
                    util.navigateToPage(this, 'Schedule__c');
                }
            }).catch((error) => {
                util.showToast(this, 'error', labels.error, error);
            }).finally(() => {
                this.loading = false;
            });
        }
    }

    onBookmarkClick(event) {
        let categoryIndex = event.target.dataset.category;
        let articleIndex = event.target.dataset.article;
        let articleCategory = this.articleCategories[categoryIndex];
        let article = articleCategory.articles[articleIndex];

        article.bookmarked = !article.bookmarked;
    }

    onArticleClick() {
        this.currentPage = PAGE_ARTICLE;
    }

    onArticleBackButtonClick() {
        this.currentPage = PAGE_HOME;
    }

}