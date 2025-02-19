<template>
  <b-form-group :label-cols="(columnLabel) ? labelCols : 0" :label="columnLabel" :state="isValid()"
    class="pf-form-chosen" :class="{ 'mb-0': !columnLabel, 'is-focus': focus, 'is-empty': !value, 'is-disabled': disabled }">
    <template v-slot:invalid-feedback>
      <icon name="circle-notch" spin v-if="!getInvalidFeedback()"></icon> {{ feedbackState }}
    </template>
    <b-input-group>
      <multiselect
        v-model="inputValue"
        v-bind="$attrs"
        v-on="forwardListeners"
        ref="input"
        :allow-empty="allowEmpty"
        :clear-on-select="clearOnSelect"
        :disabled="disabled"
        :group-values="groupValues"
        :id="id"
        :internal-search="internalSearch"
        :multiple="multiple"
        :label="label"
        :options="options"
        :options-limit="optionsLimit"
        :placeholder="placeholder"
        :preserve-search="preserveSearch"
        :searchable="searchable"
        :show-labels="false"
        :state="isValid()"
        :track-by="trackBy"
        @change.native="onChange($event)"
        @input.native="validate()"
        @keyup.native.stop.prevent="onChange($event)"
        @search-change="onSearchChange($event)"
        @open="onFocus"
        @close="onBlur"
      >
        <template v-slot:noResult>
          <b-media class="text-secondary" md="auto">
            <template v-if="loading">
              <template v-slot:aside><icon name="circle-notch" spin scale="2" class="mt-1 ml-2"></icon></template>
              <strong>{{ $t('Loading results') }}</strong>
              <b-form-text class="font-weight-light">{{ $t('Please wait...') }}</b-form-text>
            </template>
            <template v-else>
              <template v-slot:aside><icon name="search" scale="2" class="mt-1 ml-2"></icon></template>
              <strong>{{ $t('No results') }}</strong>
              <b-form-text class="font-weight-light">{{ $t('Please refine your search.') }}</b-form-text>
            </template>
          </b-media>
        </template>
      </multiselect>
      <b-input-group-append v-if="readonly || disabled">
        <b-button class="input-group-text" tabindex="-1" disabled><icon name="lock"></icon></b-button>
      </b-input-group-append>
    </b-input-group>
    <b-form-text v-if="text" v-html="text"></b-form-text>
  </b-form-group>
</template>

<script>
import Multiselect from 'vue-multiselect'
import 'vue-multiselect/dist/vue-multiselect.min.css'
import { createDebouncer } from 'promised-debounce'
import pfMixinValidation from '@/components/pfMixinValidation'

export default {
  name: 'pf-form-chosen',
  mixins: [
    pfMixinValidation
  ],
  components: {
    Multiselect
  },
  props: {
    value: {
      default: null
    },
    clearOnSelect: {
      type: Boolean,
      default: false
    },
    columnLabel: {
      type: String
    },
    labelCols: {
      type: Number,
      default: 3
    },
    text: {
      type: String,
      default: null
    },
    /* multiselect props */
    allowEmpty: {
      type: Boolean,
      default: true
    },
    // Add a proxy on our inputValue to modify set/get for simple external models.
    // https://github.com/shentao/vue-multiselect/issues/385#issuecomment-418881148
    collapseObject: {
      type: Boolean,
      default: true
    },
    disabled: {
      type: Boolean,
      default: false
    },
    groupValues: {
      type: String
    },
    id: {
      type: String
    },
    internalSearch: {
      type: Boolean,
      default: true
    },
    label: {
      type: String,
      default: 'text'
    },
    loading: {
      type: Boolean,
      default: false
    },
    multiple: {
      type: Boolean,
      default: false
    },
    options: {
      type: Array,
      default: () => { return [] }
    },
    optionsLimit: {
      type: Number,
      default: 100
    },
    optionsSearchFunction: {
      type: Function
    },
    optionsSearchFunctionInitialized: { // true after first `optionsSearchFunction` call (for preloading)
      type: Boolean,
      default: false
    },
    placeholder: {
      type: String,
      default: null
    },
    preserveSearch: {
      type: Boolean,
      default: false
    },
    searchable: {
      type: Boolean,
      default: true
    },
    trackBy: {
      type: String,
      default: 'value'
    }
  },
  data () {
    return {
      focus: false
    }
  },
  computed: {
    inputValue: {
      get () {
        const currentValue = this.value || ((this.multiple) ? [] : null)
        if (this.collapseObject) {
          const options = (!this.groupValues)
            ? (this.options ? this.options : [])
            : this.options.reduce((options, group, index) => { // flatten group
              options.push(...group[this.groupValues])
              return options
            }, [])
          if (options.length === 0) { // no options
            return (this.multiple)
              ? [...new Set(currentValue.map(value => {
                return { [this.trackBy]: value, [this.label]: value }
              }))]
              : { [this.trackBy]: currentValue, [this.label]: currentValue }
          } else { // is options
            return (this.multiple)
              ? [...new Set(currentValue.map(value => {
                return options.find(option => option[this.trackBy] === value) || { [this.trackBy]: value, [this.label]: value }
              }))]
              : options.find(option => option[this.trackBy] === currentValue) || { [this.trackBy]: currentValue, [this.label]: currentValue }
          }
        }
        return currentValue
      },
      set (newValue) {
        if (this.collapseObject) {
          newValue = (this.multiple)
            ? [...new Set(newValue.map(value => value[this.trackBy]))]
            : (newValue && newValue[this.trackBy])
        }
        this.$emit('input', newValue)
      }
    },
    forwardListeners () {
      const { input, ...listeners } = this.$listeners
      return listeners
    }
  },
  methods: {
    onFocus (event) {
      this.focus = true
      this.onSearchChange(this.inputValue)
    },
    onBlur (event) {
      this.focus = false
      this.onSearchChange(this.inputValue)
    },
    onSearchChange (query) {
      if (this.optionsSearchFunction) {
        if (!this.$debouncer) {
          this.$debouncer = createDebouncer()
        }
        this.loading = true
        this.$debouncer({
          handler: () => {
            Promise.resolve(this.optionsSearchFunction(this, query)).then(options => {
              this.loading = false
              this.options = options
            }).catch(() => {
              this.loading = false
            }).finally(() => {
              this.optionsSearchFunctionInitialized = true
            })
          },
          time: 300
        })
      }
    }
  },
  watch: {
    value: {
      handler (a, b) {
        this.onSearchChange(a) // prime the searchable cache with our current `value`
      },
      immediate: true
    }
  }
}
</script>

<style lang="scss">
/**
 * Adjust is-invalid and is-focus borders
 */
.pf-form-chosen {

  /* show placeholder even when empty */
  &.is-empty {
    .multiselect__input,
    .multiselect__placeholder {
      position: relative !important;
      width: 100% !important;
    }
    .multiselect__placeholder {
      display: none;
    }
  }
  &.is-empty:not(.is-focus) {
    .multiselect__single {
      display: none;
    }
  }

  .multiselect__loading-enter-active,
  .multiselect__loading-leave-active,
  .multiselect__input,
  .multiselect__single,
  .multiselect__tags,
  .multiselect__tag-icon,
  .multiselect__select,
  .multiselect-enter-active,.multiselect-leave-active {
    transition: $custom-forms-transition;
  }

  .multiselect {
      position: relative;
      flex: 1 1 auto;
      width: 1%;
      min-height: auto;
      border-width: 1px;
      margin-bottom: 0;
      font-size: $font-size-base;
  }
  .multiselect__tags,
  .multiselect__option {
    min-height: $input-height;
    padding: $input-padding-y $input-padding-x;
    font-size: $font-size-base;
    line-height: $input-line-height;
  }
  .multiselect__tags {
    padding-right: 40px;
    border: 1px solid $input-focus-bg;
    background-color: $input-focus-bg;
    @include border-radius($border-radius);
    outline: 0;
    .multiselect__input {
      max-width: 100%;
    }
    span > span.multiselect__single { /* placeholder */
      color: $input-placeholder-color;
      // Override Firefox's unusual default opacity; see https://github.com/twbs/bootstrap/pull/11526.
      opacity: 1;
    }
  }
  .multiselect__select {
    top: 0px;
    right: 10px;
    bottom: 0px;
    width: auto;
    height: auto;
    padding: 0px;
  }
  .multiselect__tag {
    margin-bottom: 0px;
    background-color: $secondary;
  }
  .multiselect__tag-icon {
    &:hover {
      background-color: inherit;
      color: lighten($secondary, 15%);
    }
    &:after {
      color: $component-active-color;
    }
  }
  .multiselect__input,
  .multiselect__single {
    padding: 0px;
    margin: 0px;
    background-color: transparent;
    color: $input-color;
    font-size: $font-size-base;
    &::placeholder {
      color: $input-placeholder-color;
    }
  }
  .multiselect__placeholder {
    padding-top: 0px;
    padding-bottom: $input-padding-y;
    margin-bottom: 0px;
    color: $input-placeholder-color;
    font-size: $font-size-base;
    line-height: $input-line-height;
  }
  .multiselect__content-wrapper {
    z-index: $zindex-popover;
    border: $dropdown-border-width solid $dropdown-border-color;
    @include border-radius($dropdown-border-radius);
    @include box-shadow($dropdown-box-shadow);
  }
  .multiselect--active:not(.multiselect--above) {
    .multiselect__content-wrapper {
      border-top-width: 0px;
      border-bottom-width: 1px;
      border-top-left-radius: 0 !important;
      border-top-right-radius: 0 !important;
      border-bottom-left-radius: $border-radius !important;
      border-bottom-right-radius: $border-radius !important;
    }
  }
  .multiselect--above {
    .multiselect__content-wrapper {
      border-bottom-width: 0px;
      border-bottom-left-radius: 0 !important;
      border-bottom-right-radius: 0 !important;
    }
  }
  .multiselect__option--highlight {
    background-color: $dropdown-link-active-bg;
    color: $dropdown-link-active-color;
  }
  .multiselect--disabled {
    background-color: $input-disabled-bg;
    opacity: 1;
    .multiselect__tags,
    .multiselect__single {
      background-color: $input-disabled-bg;
    }
    .multiselect__select {
      background-color: transparent;
    }
  }
  &.is-focus {
    .multiselect__tags {
      border-color: $input-focus-border-color;
    }
  }
  &.is-invalid {
    .multiselect__tags {
      border-color: $form-feedback-invalid-color;
    }
  }
}
</style>
