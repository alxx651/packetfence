<template>
  <b-form @submit.prevent="(isNew || isClone) ? create($event) : save($event)" class="pf-config-view">
    <b-card no-body v-bind="$attrs" :class="cardClass">
      <b-card-header>
        <slot name="header">
          <b-button-close @click="close" v-b-tooltip.hover.left.d300 :title="$t('Close [ESC]')"><icon name="times"></icon></b-button-close>
          <h4 class="mb-0">
            <span>{{ $t('Configuration Template') }}</span>
          </h4>
        </slot>
      </b-card-header>
      <b-tabs v-if="form.fields[0].tab || form.fields.length > 1" v-model="tabIndex" :key="tabKey" card>
        <template v-for="(tab, t) in form.fields">
          <b-tab v-if="!('if' in tab) || tab.if" :key="t"
            :disabled="tab.disabled"
            :title-link-class="{ 'text-danger': getTabErrorCount(t) > 0 }"
            :title="tab.tab"
            no-body
          ></b-tab>
        </template>
      </b-tabs>
      <template v-for="(tab, t) in form.fields">
        <div class="card-body" v-if="tab.fields" v-show="t === tabIndex" :key="t">
          <template v-for="row in tab.fields">
            <b-form-group v-if="!('if' in row) || row.if" :key="row.key"
              :label-cols="('label' in row && row.fields) ? form.labelCols : 0" :label="row.label" :label-size="row.labelSize" :label-class="[(row.label && row.fields) ? '' : 'text-left', (row.fields) ? '' : 'offset-sm-3']"
              :state="isValid()" :invalid-feedback="getInvalidFeedback()"
              class="input-element" :class="{ 'mb-0': !row.label, 'pt-3': !row.fields }"
            >
              <b-input-group>
                <template v-for="field in row.fields">
                  <span v-if="field.text" :key="field.index" :class="field.class">{{ field.text }}</span>
                  <component v-else-if="!('if' in field) || field.if"
                    v-bind="field.attrs"
                    v-on="kebabCaseListeners(field.listeners)"
                    :key="field.key"
                    :keyName="field.key"
                    :is="field.component || defaultComponent"
                    :is-loading="isLoading"
                    :vuelidate="getVuelidateModel(field.key)"
                    :class="getClass(row, field)"
                    :value="getValue(field.key)"
                    :disabled="(field.attrs && field.attrs.disabled) || disabled"
                    @input="setValue(field.key, $event)"
                    @validations="setComponentValidations(field.key, $event)"
                    v-once
                  ></component>
                </template>
              </b-input-group>
              <b-form-text v-if="row.text" v-html="row.text"></b-form-text>
            </b-form-group>
          </template>
        </div>
      </template>
      <slot name="footer">
        <b-card-footer @mouseenter="vuelidate.$touch()">
          <pf-button-save :disabled="invalidForm" :is-loading="isLoading">{{ isNew? $t('Create') : $t('Save') }}</pf-button-save>
          <pf-button-delete v-show="isDeletable" class="ml-1" :disabled="isLoading" :confirm="$t('Delete Config?')" @on-delete="remove($event)"/>
        </b-card-footer>
      </slot>
    </b-card>
  </b-form>
</template>

<script>
import uuidv4 from 'uuid/v4'
import pfButtonSave from '@/components/pfButtonSave'
import pfButtonDelete from '@/components/pfButtonDelete'
import pfFormInput from '@/components/pfFormInput'
import pfMixinValidation from '@/components/pfMixinValidation'
import { createDebouncer } from 'promised-debounce'

export default {
  name: 'pfConfigView',
  components: {
    pfButtonSave,
    pfButtonDelete
  },
  mixins: [
    pfMixinValidation
  ],
  props: {
    form: {
      type: Object,
      required: true
    },
    model: {
      type: Object,
      required: true
    },
    vuelidate: {
      type: Object,
      required: true
    },
    isLoading: {
      type: Boolean
    },
    isNew: {
      type: Boolean
    },
    isClone: {
      type: Boolean
    },
    initialTabIndex: {
      type: Number,
      default: 0
    },
    disabled: {
      type: Boolean,
      default: false
    },
    cardClass: {
      type: String
    }
  },
  data () {
    return {
      tabKey: uuidv4(), // control tabs DOM rendering
      tabIndex: this.initialTabIndex,
      componentValidations: {}
    }
  },
  computed: {
    defaultComponent () {
      return pfFormInput
    },
    isDeletable () {
      if (this.isNew || this.isClone || ('not_deletable' in this.model && this.model.not_deletable)) {
        return false
      }
      return true
    }
  },
  methods: {
    close (event) {
      this.$emit('close', event)
    },
    create (event) {
      this.$emit('create', event)
    },
    save (event) {
      this.$emit('save', event)
    },
    remove (event) {
      this.$emit('remove', event)
    },
    getValue (key, model = this.model) {
      if (key) {
        if (key.includes('.')) { // handle dot-notation keys ('.')
          const [ first, ...remainder ] = key.split('.')
          return this.getValue(remainder.join('.'), model[first])
        }
        return model[key]
      } else {
        return model
      }
    },
    setValue (key, value, model = this.model) {
      if (key.includes('.')) { // handle dot-notation keys ('.')
        const [ first, ...remainder ] = key.split('.')
        if (!(first in model)) this.$set(model, first, {})
        return this.setValue(remainder.join('.'), value, model[first])
      }
      this.$set(model, key, value)
    },
    getVuelidateModel (key, model = this.vuelidate) {
      if (key) {
        if (key.includes('.')) { // handle dot-notation keys ('.')
          const [ first, ...remainder ] = key.split('.')
          return this.getVuelidateModel(remainder.join(','), model[first])
        }
        return model[key]
      }
    },
    setComponentValidations (key, validations) {
      this.$set(this.componentValidations, key, validations)
      this.emitValidations()
    },
    getExternalValidations () {
      const eachFieldValue = {}
      const setEachFieldValue = (key, value, model = eachFieldValue) => {
        if (key.includes('.')) { // handle dot-notation keys ('.')
          const [ first, ...remainder ] = key.split('.')
          if (!(first in model)) model[first] = {}
          setEachFieldValue(remainder.join('.'), value, model[first])
          return
        }
        this.$set(model, key, value)
      }
      if (this.form.fields.length > 0) {
        this.form.fields.forEach(tab => {
          if ('fields' in tab && (!('if' in tab) || tab.if)) {
            tab.fields.forEach(row => {
              if ('fields' in row && (!('if' in row) || row.if)) {
                row.fields.forEach(field => {
                  if (field.key) {
                    setEachFieldValue(field.key, {})
                    if ('validators' in field) {
                      setEachFieldValue(field.key, field.validators)
                    }
                  }
                })
              }
            })
          }
        })
      }
      // merge component validations
      Object.keys(this.componentValidations).forEach(key => {
        if (key in eachFieldValue) {
          eachFieldValue[key] = { ...eachFieldValue[key], ...this.componentValidations[key] }
        } else {
          eachFieldValue[key] = this.componentValidations[key]
        }
      })
      Object.freeze(eachFieldValue)
      return eachFieldValue
    },
    emitValidations () {
      this.$emit('validations', this.getExternalValidations())
    },
    getClass (row, field) {
      let c = ['px-0'] // always remove padding
      if ('attrs' in field && `class` in field.attrs) { // if class is defined
        c.push(field.attrs.class) // use manual definition
      } else if (row.fields.length === 1) { // else if row is singular
        c.push('col-sm-12') // use entire width
      }
      return c.join(' ')
    },
    getTabErrorCount (tabIndex) {
      return this.form.fields[tabIndex].fields.reduce((tabCount, tab) => {
        if (!('fields' in tab)) return tabCount // ignore labels
        return tab.fields.reduce((fieldCount, field) => {
          if (field.key in this.vuelidate && this.vuelidate[field.key].$anyError) {
            fieldCount++
          }
          return fieldCount
        }, tabCount)
      }, 0)
    },
    kebabCaseListeners (listeners) {
      if (listeners) {
        let kebabedListeners = {}
        Object.keys(listeners).forEach(key => {
          let kebabKey = ''
          key.split('').forEach((char, index) => {
            if (index > 0 && char === char.toUpperCase()) {
              kebabKey += '-' + char.toLowerCase()
            } else {
              kebabKey += char
            }
          })
          kebabedListeners[kebabKey] = listeners[key]
        })
        return kebabedListeners
      }
    }
  },
  watch: {
    model: {
      handler: function () {
        if (!this.$debouncerModel) {
          this.$debouncerModel = createDebouncer()
        }
        this.$debouncerModel({
          handler: () => {
            this.emitValidations()
            if (this.vuelidate.$dirty) {
              this.$nextTick(() => {
                this.vuelidate.$touch()
              })
            }
          },
          time: 300
        })
      },
      deep: true
    }
  },
  mounted () {
    this.$store.commit('session/FORM_OK')
  }
}
</script>

<style lang="scss">
.pf-config-view {
  .input-group > span {
    display: flex;
    justify-content: center;
    align-items: center;
  }
}
</style>
