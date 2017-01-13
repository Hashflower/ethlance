(ns ethlance.pages.search-freelancers-page
  (:require
    [cljs-react-material-ui.icons :as icons]
    [cljs-react-material-ui.reagent :as ui]
    [ethlance.components.category-select-field :refer [category-select-field]]
    [ethlance.components.checkbox-group :refer [checkbox-group]]
    [ethlance.components.country-auto-complete :refer [country-auto-complete]]
    [ethlance.components.language-select-field :refer [language-select-field]]
    [ethlance.components.misc :as misc :refer [col row paper-thin row-plain a]]
    [ethlance.components.skills-chip-input :refer [skills-chip-input]]
    [ethlance.components.skills-chips :refer [skills-chips]]
    [ethlance.components.slider-with-counter :refer [slider-with-counter]]
    [ethlance.components.star-rating :refer [star-rating]]
    [ethlance.components.truncated-text :refer [truncated-text]]
    [ethlance.styles :as styles]
    [ethlance.utils :as u]
    [goog.string :as gstring]
    [re-frame.core :refer [subscribe dispatch]]
    [reagent.core :as r]))

(defn filter-sidebar []
  (let [form-data (subscribe [:form/search-freelancers])]
    (fn []
      (let [{:keys [:search/category :search/skills :search/min-avg-rating
                    :search/min-freelancer-ratings-count :search/min-hourly-rate :search/max-hourly-rate
                    :search/country :search/language :search/offset :search/limit]} @form-data]
        [misc/call-on-change
         {:load-on-mount? true
          :args @form-data
          :on-change #(dispatch [:after-eth-contracts-loaded [:contract.search/search-freelancers @form-data]])}
         [paper-thin
          [category-select-field
           {:value category
            :full-width true
            :on-change #(dispatch [:form.search/set-value :search/category %3])}]
          [misc/subheader "Min. Rating"]
          [star-rating
           {:value (u/rating->star min-avg-rating)
            :on-star-click #(dispatch [:form.search/set-value :search/min-avg-rating
                                       (u/star->rating %1)])}]
          [misc/ether-field
           {:floating-label-text "Min. Hourly Rate (Ether)"
            :value min-hourly-rate
            :full-width true
            :on-change #(dispatch [:form.search/set-value :search/min-hourly-rate %])}]
          [misc/ether-field
           {:floating-label-text "Max. Hourly Rate (Ether)"
            :value max-hourly-rate
            :full-width true
            :on-change #(dispatch [:form.search/set-value :search/max-hourly-rate %])}]
          [misc/text-field
           {:floating-label-text "Min. Number of Feedbacks"
            :type :number
            :value min-freelancer-ratings-count
            :full-width true
            :min 0
            :on-change #(dispatch [:form.search/set-value :search/min-freelancer-ratings-count %2])}]
          [country-auto-complete
           {:value country
            :full-width true
            :on-new-request #(dispatch [:form.search/set-value :search/country %2])}]
          [language-select-field
           {:value language
            :full-width true
            :on-new-request #(dispatch [:form.search/set-value :search/language %2])}]
          [misc/search-reset-button]]]))))

(defn change-page [new-offset]
  (dispatch [:form.search/set-value :search/offset new-offset])
  (dispatch [:window/scroll-to-top]))

(defn search-results []
  (let [list (subscribe [:list/search-freelancers])
        selected-skills (subscribe [:form/search-freelancer-skills])
        form-data (subscribe [:form/search-freelancers])
        xs-width? (subscribe [:window/xs-width?])]
    (fn []
      (let [{:keys [loading? items]} @list
            {:keys [:search/offset :search/limit]} @form-data
            xs? @xs-width?]
        [misc/search-results
         {:items-count (count items)
          :loading? loading?
          :offset offset
          :limit limit
          :no-items-found-text "No freelancers match your search criteria"
          :no-more-items-text "No more freelancers found"
          :next-button-text "Next"
          :prev-button-text "Previous"
          :on-page-change change-page}
         (for [{:keys [:freelancer/avg-rating :freelancer/hourly-rate :freelancer/job-title
                       :freelancer/ratings-count :freelancer/skills
                       :user/id :user/name :user/gravatar :user/country] :as item} items]
           [row-plain
            {:key id :middle "xs" :center "xs" :start "sm"}
            [a
             {:route :freelancer/detail
              :route-params {:user/id id}}
             [ui/avatar
              {:size (if xs? 80 55)
               :src (u/gravatar-url gravatar id)
               :style (if xs?
                        {:margin-bottom 10}
                        {:margin-right 10})}]]
            [:div
             {:style (when xs? styles/full-width)}
             [:h2 [a {:style styles/primary-text
                      :route :freelancer/detail
                      :route-params {:user/id id}}
                   name]]
             [:div {:style (merge styles/fade-text
                                  (when @xs-width? {:margin-top 5}))} job-title]]
            [row-plain
             {:middle "xs" :center "xs" :start "sm"
              :style styles/freelancer-search-result-info-row}
             [star-rating
              {:value (u/rating->star avg-rating)
               :small? true}]
             [:span [:span {:style (merge styles/dark-text
                                          styles/freelancer-info-item)}
                     (u/eth hourly-rate)] " per hour"]
             [:span
              {:style styles/freelancer-info-item}
              ratings-count (u/pluralize " feedback" ratings-count)]
             [misc/country-marker
              {:country country
               :row-props {:style styles/freelancer-info-item}}]]
            [skills-chips
             {:selected-skills skills
              :on-touch-tap (fn [skill-id]
                              (when-not (contains? (set @selected-skills) skill-id)
                                (dispatch [:form.search/set-value :search/skills
                                           (conj (into [] @selected-skills) skill-id)])))}]
            [misc/hr-small]])]))))

(defn skills-input []
  (let [selected-skills (subscribe [:form/search-freelancer-skills])]
    (fn []
      [paper-thin
       [skills-chip-input
        {:value @selected-skills
         :hint-text "Type skills you want a freelancer to have"
         :on-change #(dispatch [:form.search/set-value :search/skills %1])}]])))

(defn search-freelancers-page []
  [misc/search-layout
   [filter-sidebar]
   [skills-input]
   [search-results]])
