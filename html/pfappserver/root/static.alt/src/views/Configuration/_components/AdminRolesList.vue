<template>
  <b-card no-body>
    <pf-config-list
      :config="config"
    >
      <template v-slot:pageHeader>
        <b-card-header>
          <h4 class="mb-3">
            {{ $t('Admin Roles') }}
            <pf-button-help class="ml-1" url="PacketFence_Installation_Guide.html#_admin_access" />
          </h4>
          <p class="mb-0" v-t="'Define roles with specific access rights to the Web administration interface. Roles are assigned to users depending on their authentication source.'"></p>
        </b-card-header>
      </template>
      <template v-slot:buttonAdd>
        <b-button variant="outline-primary" :to="{ name: 'newAdminRole' }">{{ $t('New Admin Role') }}</b-button>
      </template>
      <template v-slot:emptySearch="state">
        <pf-empty-table :isLoading="state.isLoading">{{ $t('No admin roles found') }}</pf-empty-table>
      </template>
      <template v-slot:cell(buttons)="item">
        <span class="float-right text-nowrap">
          <pf-button-delete size="sm" v-if="!item.not_deletable" variant="outline-danger" class="mr-1" :disabled="isLoading" :confirm="$t('Delete Admin Role?')" @on-delete="remove(item)" reverse/>
          <b-button size="sm" variant="outline-primary" class="mr-1" @click.stop.prevent="clone(item)">{{ $t('Clone') }}</b-button>
        </span>
      </template>
    </pf-config-list>
  </b-card>
</template>

<script>
import pfButtonDelete from '@/components/pfButtonDelete'
import pfButtonHelp from '@/components/pfButtonHelp'
import pfConfigList from '@/components/pfConfigList'
import pfEmptyTable from '@/components/pfEmptyTable'
import {
  pfConfigurationAdminRoleListConfig as config
} from '@/globals/configuration/pfConfigurationAdminRoles'

export default {
  name: 'admin-roles-list',
  components: {
    pfButtonDelete,
    pfButtonHelp,
    pfConfigList,
    pfEmptyTable
  },
  props: {
    storeName: { // from router
      type: String,
      default: null,
      required: true
    }
  },
  data () {
    return {
      config: config(this)
    }
  },
  methods: {
    clone (item) {
      this.$router.push({ name: 'cloneAdminRole', params: { id: item.id } })
    },
    remove (item) {
      this.$store.dispatch(`${this.storeName}/deleteAdminRole`, item.id).then(response => {
        this.$router.go() // reload
      })
    }
  }
}
</script>
